//
//  PlaybackService.swift
//  Playback
//
//  Created by xueqooy on 2022/12/16.
//

import Combine
import Foundation
import XKit
import PlaybackFoundation

/**
**1. Attach the player:**

 - The player will share between the same item.
 - The player view size matches the container view.
 - Only one item can play at a time; playing a new item pauses others.
 - Previous players are removed from the container when a new player is attached.
 ```swift
 // Identical playing content is distinguished by `tag`, for example, different cells in the list play the same content.
 let playbackItem = PlaybackItem(type: .video, contentString: videoURLString, tag: tag)
 playbackService.attachPlayer(to: videoContainerView, with: playbackItem)
 ```
 You can also manually remove the player:
 ```swift
 playbackService.removePlayer(from: videoContainerView)
 ```

 Playback starts with user interaction, but you can programmatically pause it:
 ```swift
 playbackService.pauseAllPlayers()
 ```

 To stop the playback and remove the player from the container, call:
 ```swift
 playbackService.stopPlayer(for: item) 
 playbackService.stopAllPlayers()
 ```

 **2. Pause playback when the player moves off-screen in a scroll view:**
 ```swift
 // for video
 playbackService.preferences.shouldAutoPauseVideoOnScrollView = true
 // for audio
 playbackService.preferences.shouldAutoPauseAudioOnScrollView = true
 ```

 **3. Adapt to device rotation:**

 If the app only supports portrait mode but you want to autorotate fullscreen when the device orientation changes:
 ```swift
 playbackService.preferences.orientationsForApplyingRotateTransform = [.landscapeLeft, .landscapeRight, .portraitUpsideDown]
 ```

 If the app supports all orientations, set:
 ```swift
 playbackService.preferences.orientationsForApplyingRotateTransform = []
 ```

 **4. Customize video presentation view:**

 To customize the video player view, implement a new class that conforms to the `VideoPresentable` protocol and set it to 
 ```swift
 playbackService.preferences.videoPresentationViewType
 ```

 **5 Customize playback control view:**

 To customize the playback control view, implement a new class that conforms to the `PlaybackControllable` protocol and set it to 
 ```swift
 // for video
 playbackService.preferences.videoControlType
 // for audio
 playbackService.preferences.audioControlType
 ```

 **6. Customize playback control plugins:**

 To customize the playback control plugins, create a new type that conforms to the `PlayerPluginSet` protocol and set it to 
 ```swift
 // for video
 playbackService.preferences.videoPlayerPluginSet
 // for audio
 playbackService.preferences.audioPlayerPluginSet 
 ``` 

 **7 Customize item parser:**

 To customize the item parser, implement a new class that conforms to the `PlaybackItemParseable` protocol and add it to 
 ```swift
 PlaybackURLManager.shared.additionalParsers
```
 
 **8. Directly use the player:**

 If you want to manage the player yourself and do not want the player to be shared or removed when not needed, you can directly use the `HybridMediaPlayer` or `EmbedVideoPlayer`, which provide direct playback functionality.

 ```swift
 // Play video or audio
 let hint = PlaybackHint(format: media.format, title: resource.title)
 let engineType: PlayerEngineType = media.isAVPlayerSupportedFormat ? .av : .vlc
 let player: HybridMediaPlayer = media.isAudio ? .defaultAudioPlayer(engineType: engineType) : .defaultVideoPlayer(engineType: engineType)
 player.hint = hint
 player.url = media.url
 player.containerView = contaienrView
 
 // Play youtube embed video
 let player = EmbedVideoPlayer()
 player.url = youtubeEmbedURL
 player.containerView = contaienrView
 ```
 */
@MainActor public class PlaybackService: NSObject {
    public struct Preferences {
        /// The fullscreen orientations for applying rotate transform when device orientation changed, default is `kNilOptions`
        public var orientationsForApplyingRotateTransform: UIInterfaceOrientationMask = []
        public var videoPresentationViewType: VideoPresentable.Type = DefaultVideoPresentationView.self
        public var videoControlType: PlaybackControllable.Type = DefaultVideoControlView.self
        public var videoPlayerPluginSet: PlayerPluginSet? = DefaultVideoPlayerPlugins.all
        public var audioControlType: PlaybackControllable.Type = DefaultAudioControlView.self
        public var audioPlayerPluginSet: PlayerPluginSet?
        public var shouldAutoPauseVideoOnScrollView: Bool = true
        public var shouldAutoPauseAudioOnScrollView: Bool = false
    }

    public static let shared = PlaybackService()

    public var isPlayingPublisher: some Publisher<Void, Never> {
        isPlayingSubject.receive(on: RunLoop.main)
    }

    public var preferences = Preferences() {
        didSet {
            for player in playerCache.players {
                if let hybridPlayer = player as? HybridMediaPlayer {
                    hybridPlayer.orientationsForApplyingRotateTransform =
                        preferences.orientationsForApplyingRotateTransform
                }

                if let mediaType = player.containerView?.playbackItem?.mediaType {
                    switch mediaType {
                    case .video:
                        if preferences.shouldAutoPauseVideoOnScrollView {
                            player.maybeAddScrollingObserverForAutoPause()
                        } else {
                            player.removeScrollingObserverForAutoPause()
                        }
                    case .audio:
                        if preferences.shouldAutoPauseAudioOnScrollView {
                            player.maybeAddScrollingObserverForAutoPause()
                        } else {
                            player.removeScrollingObserverForAutoPause()
                        }
                    }
                }
            }

            playerCache.trim(single: false)
        }
    }

    public private(set) lazy var playerCache: PlayerCache = createPlayerCache()

    private var urlManager = PlaybackURLManager.shared
    private let isPlayingSubject = PassthroughSubject<Void, Never>()
    private var scrollingObservation: AnyCancellable?
    private var audioInterruptedObservation: AnyCancellable?
    private var containerViewForItem = [PlaybackItem: Weak<UIView>]()

    /// Attach video player view to container view.
    ///
    /// - parameter containerView: container for attaching player view
    /// - parameter item: Identify a  playback item
    /// - parameter hint: Hint information for playback
    ///
    /// - Note: A case, Two identical attach requests are initiated at the same time, but they are applied to different views, The last request's view shall prevail.
    /// Another case, Two different attach requests are added to the same view, and the view displays the latest requested item.
    ///
    @discardableResult
    public func attachPlayer(
        to containerView: UIView, with item: PlaybackItem, hint: PlaybackHint? = nil
    ) async -> PlaybackURLResult? {
        // Remove previous player from container
        if containerView.playbackItem != item {
            removePlayer(from: containerView)
        }

        // Record last item for container and container for item
        containerView.playbackItem = item
        containerViewForItem[item] = Weak(value: containerView)

        // Parse url from content string (suspend point)
        guard let result = await urlManager.parse(item) else {
            return nil
        }

        // Get player from cache or new
        var player = playerCache.getPlayer(for: item)
        if player == nil /* || player?.isStopped == true */ {
            player = createPlayer(for: result.type, item: item, hint: hint)
            playerCache.cachePlayer(player!, for: item)
        }
        playerCache.bringUpToDate(item)

        // Attach player to container
        player!.hint = hint
        player!.url = result.url
        if containerView.playbackItem == item {
            player!.containerView = containerViewForItem[item]?.value

            switch item.mediaType {
            case .video:
                if preferences.shouldAutoPauseVideoOnScrollView {
                    player!.maybeAddScrollingObserverForAutoPause()
                } else {
                    player!.removeScrollingObserverForAutoPause()
                }
            case .audio:
                if preferences.shouldAutoPauseAudioOnScrollView {
                    player!.maybeAddScrollingObserverForAutoPause()
                } else {
                    player!.removeScrollingObserverForAutoPause()
                }
            }
        }

        return result
    }

    public func removePlayer(from view: UIView) {
        if let playbackItem = view.playbackItem,
           let player = playerCache.getPlayer(for: playbackItem)
        {
            if player.containerView === view {
                player.containerView = nil
            }
        }
    }

    public func pauseAllPlayers() {
        pausePlayers(exclusion: nil)
    }

    public func stopPlayer(for item: PlaybackItem) {
        Asserts.mainThread()

        let player = playerCache.getPlayer(for: item)
        player?.stop()
    }

    public func stopAllPlayers() {
        Asserts.mainThread()

        playerCache.players.forEach { $0.stop() }
        playerCache = createPlayerCache()
    }

    // MARK: Private methods

    private func createPlayer(
        for urlType: PlaybackURLType, item: PlaybackItem, hint: PlaybackHint?
    ) -> any Player {
        let player: any Player

        switch urlType {
        case .embed:
            player = EmbedVideoPlayer()

        case .file, .network:
            let usesVLCEngine: Bool = if let format = hint?.format?.lowercased() {
                !AVPlayerSupportedFormat.contains(format)
            } else {
                true
            }

            let videoView: VideoPresentable? = if item.mediaType == .video {
                preferences.videoPresentationViewType.init()
            } else {
                nil
            }

            let playbackEngine: PlaybackEngine =
                if usesVLCEngine {
                    VLCPlaybackEngine(view: videoView)
                } else {
                    AVPlaybackEngine(view: videoView)
                }

            let controlView = if item.mediaType == .video {
                preferences.videoControlType.init()
            } else {
                preferences.audioControlType.init()
            }

            let playerPluginSet = if item.mediaType == .video {
                preferences.videoPlayerPluginSet
            } else {
                preferences.audioPlayerPluginSet
            }

            let hybridPlayer = HybridMediaPlayer(engine: playbackEngine, controlView: controlView, pluginSet: playerPluginSet)
            hybridPlayer.orientationsForApplyingRotateTransform = preferences.orientationsForApplyingRotateTransform
            player = hybridPlayer
        }

        player.isPlayingChanged = { [weak self] player in
            if let self, player.isPlaying {
                self.pausePlayers(exclusion: player)
                self.isPlayingSubject.send(())
            }
        }
        return player
    }

    private func createPlayerCache() -> PlayerCache {
        let playerCache = PlayerCache()
        playerCache.playerDidRemove = { player, _ in
            player.stop()
        }
        return playerCache
    }

    private func pausePlayers(exclusion: Player?) {
        let players: [Player] = playerCache.players
        players.filter {
            $0 !== exclusion
        }.forEach {
            $0.pause()
        }
    }

    private func activateAudioSessionIfNeeded() {
        let audioSessionController = AudioSessionController.shared

        if audioInterruptedObservation == nil {
            audioInterruptedObservation = audioSessionController.interruptionPublisher
                .sink { [weak self] in
                    guard let self else { return }

                    switch $0 {
                    case .began:
                        self.pauseAllPlayers()

                    case let .ended(shouldResume):
                        if shouldResume {
                            activateAudioSessionIfNeeded()
                        }
                    }
                }
        }

        guard audioSessionController.category != .playback else {
            return
        }

        do {
            try audioSessionController.set(category: .playback)
            try audioSessionController.activateSession()
        } catch {
            Logs.error(
                "Failed to activate audio session: \(error.localizedDescription)", tag: "Playback"
            )
        }
    }
}

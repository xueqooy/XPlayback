//
//  PlaybackService.swift
//  Playback
//
//  Created by xueqooy on 2022/12/16.
//

import Combine
import Foundation
import PlaybackFoundation
import XKit

/**
 **1. Attach the player:**

  - The player will share between the same item.
  - The player view size matches the container view.
  - Only one item can play at a time; playing a new item pauses others.
  - Previous players are removed from the container when a new player is attached.
  ```
  // Identical playing content is distinguished by `tag`, for example, different cells in the list play the same content.
  let playbackItem = PlaybackItem(type: .video, contentString: videoURLString, tag: tag)
  playbackService.attachPlayer(to: videoContainerView, with: playbackItem)

  // Manually remove the player
  playbackService.removePlayer(from: videoContainerView)

  // Pause or stop all player
  playbackService.pauseAllPlayers()
  playbackService.stopAllPlayers()

  // Play, pause or stop the specific player
  playbackService.playPlayer(for: item)
  playbackService.pausePlayer(for: item)
  playbackService.stopPlayer(for: item)
  ```

  **2. Pause playback when the player moves off-screen in a scroll view:**
  ```
  // for video
  playbackService.preferences.shouldAutoPauseVideoOnScrollView = true
  // for audio
  playbackService.preferences.shouldAutoPauseAudioOnScrollView = true
  ```

  **3. Adapt to device rotation:**

  If the app only supports portrait mode but you want to autorotate fullscreen when the device orientation changes:
  ```
  playbackService.preferences.orientationsForApplyingRotateTransform = [.landscapeLeft, .landscapeRight, .portraitUpsideDown]
  ```

  If the app supports all orientations, set:
  ```
  playbackService.preferences.orientationsForApplyingRotateTransform = []
  ```

  **4. Customize video presentation view:**

  To customize the video player view, implement a new class that conforms to the `VideoPresentable` protocol and set it to
  ```
  playbackService.preferences.videoPresentationViewType
  ```

  **5 Customize playback control view:**

  To customize the playback control view, implement a new class that conforms to the `PlaybackControllable` protocol and set it to
  ```
  // for video
  playbackService.preferences.videoControlType
  // for audio
  playbackService.preferences.audioControlType
  ```

  **6. Customize playback control plugins:**

  To customize the playback control plugins, create a new type that conforms to the `PlayerPluginSet` protocol and set it to
  ```
  // for video
  playbackService.preferences.videoPlayerPluginSet
  // for audio
  playbackService.preferences.audioPlayerPluginSet
  ```

  **7 Customize item parser:**

  To customize the item parser, implement a new class that conforms to the `PlaybackItemParseable` protocol and add it to
  ```
  PlaybackAssetManager.shared.additionalParsers
 ```

  **8. Directly use the player:**

  If you want to manage the player yourself and do not want the player to be shared or removed when not needed, you can directly use the `HybridMediaPlayer` or `EmbedVideoPlayer`, which provide direct playback functionality.

  ```
  // Play video or audio
  let hint = PlaybackHint(format: media.format, title: resource.title)
  let engineType: PlayerEngineType = media.isAVPlayerSupportedFormat ? .av : .vlc
  let player: HybridMediaPlayer = media.isAudio ? .defaultAudioPlayer(engineType: engineType) : .defaultVideoPlayer(engineType: engineType)
  player.hint = hint
  player.url = media.url
  player.containerView = contaienrView

  // Multi-quality asset
  let multiQualityAsset = MultiQualityAsset(items: [
    .init(url: url1, label: "720p"),
    .init(url: url2, label: "1080p"),
    .init(url: url3, label: "4K")
  ], defaultIndex: 1)
  player.multiQualityAssetController?.asset = multiQualityAsset

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
        public var qualityMenuProviderType: QualityMenuProviding.Type? = DefaultQualityMenuProvider.self
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

    private var assetManager = PlaybackAssetManager.shared
    private let isPlayingSubject = PassthroughSubject<Void, Never>()
    private var scrollingObservation: AnyCancellable?
    private var audioInterruptedObservation: AnyCancellable?
    private var containerViewForItem = [PlaybackItem: Weak<UIView>]()
    private let cancellableAssociation = Association<AnyCancellable>()

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
    ) async -> PlaybackAssetResult? {
        // Remove previous player from container
        if containerView.playbackItem != item {
            removePlayer(from: containerView)
        }

        // Record last item for container and container for item
        containerView.playbackItem = item
        containerViewForItem[item] = Weak(value: containerView)

        // Parse url from content string (suspend point)
        guard let result = await assetManager.parse(item) else {
            return nil
        }

        // Get player from cache or new
        var player = playerCache.getPlayer(for: item)
        if player == nil {
            player = createPlayer(for: result.asset, item: item, hint: hint)
            playerCache.cachePlayer(player!, for: item)
        }
        playerCache.bringUpToDate(item)

        // Attach player to container
        player!.hint = hint
        switch result.asset {
        case .embed, .local, .network:
            player!.multiQualityAssetController?.asset = nil
            player!.url = result.asset.url

        case .localWithMultiQuality, .networkWithMultiQuality:
            if let multiQualityAssetController = player!.multiQualityAssetController {
                multiQualityAssetController.asset = result.asset.mutiQualityAsset
            } else {
                player!.url = result.asset.url
            }
        }

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

    public func playbackStatePublisher(for item: PlaybackItem) -> AnyPublisher<PlaybackState, Never>? {
        let player = playerCache.getPlayer(for: item)
        return player?.playbackStatePublisher
    }

    public func playPlayer(for item: PlaybackItem) {
        let player = playerCache.getPlayer(for: item)
        player?.play()
    }

    public func pausePlayer(for item: PlaybackItem) {
        let player = playerCache.getPlayer(for: item)
        player?.pause()
    }

    public func stopPlayer(for item: PlaybackItem) {
        let player = playerCache.getPlayer(for: item)
        player?.stop()
    }

    public func pauseAllPlayers() {
        pausePlayers(exclusion: nil)
    }

    public func stopAllPlayers() {
        playerCache.players.forEach { $0.stop() }
    }

    // MARK: Private methods

    private func createPlayer(
        for asset: PlaybackAsset, item: PlaybackItem, hint: PlaybackHint?
    ) -> any Player {
        let player: any Player

        switch asset {
        case .embed:
            player = EmbedVideoPlayer()

        default:
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

            let qualityMenuProvider: QualityMenuProviding? = if let qualityMenuProviderType = preferences.qualityMenuProviderType {
                qualityMenuProviderType.init()
            } else {
                nil
            }

            let hybridPlayer = HybridMediaPlayer(engine: playbackEngine, controlView: controlView, pluginSet: playerPluginSet, qualityMenuProvider: qualityMenuProvider)
            hybridPlayer.orientationsForApplyingRotateTransform = preferences.orientationsForApplyingRotateTransform
            player = hybridPlayer
        }

        cancellableAssociation[player] = player.playbackStatePublisher
            .sink { [weak player, weak self] in
                guard let self, let player else { return }

                if $0.isPlayingOrStalled {
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

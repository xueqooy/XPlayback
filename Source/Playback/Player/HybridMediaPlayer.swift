//
//  HybridMediaPlayer.swift
//  Pods
//
//  Created by xueqooy on 2024/12/15.
//

import AVFoundation
import Combine
import PlaybackFoundation
import XKit

public enum PlaybackStyle: Equatable {
    case inline
    case fullscreen(RotationTransform)

    public var isFullscreen: Bool {
        switch self {
        case .fullscreen:
            return true

        default:
            return false
        }
    }
}

/// A player that can play both audio and video from file or remote resources..
public class HybridMediaPlayer: Player {
    public weak var containerView: UIView? {
        didSet {
            fullscreenManager?.containerView = containerView
            updateLayout()
        }
    }

    public var url: URL? {
        get { engine.url }
        set {
            if newValue == nil {
                engine.playWhenReady = false
                engine.url = nil
            } else if url != newValue {
                engine.load(from: newValue!, playWhenReady: false, initialTime: nil)
            }
        }
    }

    @EquatableState
    public var hint: PlaybackHint? {
        didSet {
            engine.coverURL = hint?.coverURL
            
            if engine.state == .idle {
                if let duration = hint?.duration {
                    self.duration = duration
                }
                if let time = hint?.time {
                    self.currentTime = time
                }
            }
            
            if let time = hint?.time {
                engine.seek(to: time)
            }
        }
    }

    public var playWhenReady: Bool {
        get { engine.playWhenReady }
        set { engine.playWhenReady = newValue }
    }

    /// The orientations for applying rotate transform when device orientation changedublic
    public var orientationsForApplyingRotateTransform: UIInterfaceOrientationMask {
        get { fullscreenManager.orientationsForApplyingRotateTransform }
        set { fullscreenManager.orientationsForApplyingRotateTransform = newValue }
    }

    public var shouldHideStatusBarForFullscreen: Bool {
        get { fullscreenManager.shouldHideStatusBar }
        set { fullscreenManager.shouldHideStatusBar = newValue }
    }

    public var playbackStatePublisher: AnyPublisher<PlaybackState, Never> {
        $playbackState.didChange
    }

    @EquatableState
    public private(set) var style: PlaybackStyle = .inline
    @EquatableState
    public private(set) var playbackState: PlaybackState = .idle
    @EquatableState
    public private(set) var duration: TimeInterval = 0
    @EquatableState
    public private(set) var currentTime: TimeInterval = 0
    @EquatableState
    public private(set) var bufferedPosition: TimeInterval = 0
    @EquatableState
    public private(set) var isMuted: Bool = false

    public private(set) var plugins = [PlayerPlugin]()

    public let multiQualityAssetController: MultiQualityAssetController?

    public let controlView: PlaybackControllable

    private var engine: PlaybackEngine
    private var playbackView: UIView { engine.view ?? controlView }
    private var fullscreenManager: FullscreenManager!
    private let systemVolumeController = SystemVolumeController.shared
    private var observations = [AnyCancellable]()

    public init(engine: PlaybackEngine, controlView: PlaybackControllable, pluginSet: PlayerPluginSet? = nil, qualityMenuProvider: QualityMenuProviding? = nil, containerView: UIView? = nil) {
        self.engine = engine
        self.controlView = controlView
        self.containerView = containerView
        if let qualityMenuProvider {
            multiQualityAssetController = MultiQualityAssetController(menuProvider: qualityMenuProvider)
            multiQualityAssetController!.attach(to: self)
        } else {
            multiQualityAssetController = nil
        }

        initialize(with: pluginSet)
    }

    public func load(from url: URL, playWhenReady: Bool, initialTime: TimeInterval? = nil) {
        if url != self.url {
            engine.load(from: url, playWhenReady: playWhenReady, initialTime: initialTime)
        } else {
            engine.playWhenReady = playWhenReady

            if let initialTime {
                engine.seek(to: initialTime)
            }
        }
    }

    public func play() {
        engine.play()
    }

    public func pause() {
        engine.pause()
    }

    public func stop() {
        engine.stop()
    }

    public func seek(to time: TimeInterval) {
        currentTime = time
        engine.seek(to: time)
    }

    public func seek(by seconds: TimeInterval) {
        currentTime = engine.currentTime + seconds
        engine.seek(by: seconds)
    }

    public func setMuted(_ isMuted: Bool) {
        setSystemVolumeMuted(isMuted)
    }

    public func setRate(_ rate: Float) {
        engine.rate = rate
    }

    public func enterFullscreen() {
        fullscreenManager?.enterFullscreen()
    }

    public func exitFullscreen() {
        fullscreenManager?.exitFullscreen()
    }

    public func thumbnail(at time: TimeInterval, size: CGSize) async -> UIImage? {
        await engine.thumbnail(at: time, size: size)
    }

    public func addPlugin(_ plugin: PlayerPlugin) {
        guard plugins.firstIndex(where: { $0 === plugin }) == nil else { return }

        plugins.append(plugin)
        plugin.attach(to: self)
    }

    public func removePlugin(_ plugin: PlayerPlugin) {
        guard let index = plugins.firstIndex(where: { $0 === plugin }) else { return }

        plugin.detach()
        plugins.remove(at: index)
    }

    // MARK: - Private

    private func initialize(with pluginSet: PlayerPluginSet?) {
        controlView.attach(to: self)

        systemVolumeController.start()
        systemVolumeController.volumeChangedPublisher
            .sink { [weak self] in
                guard let self else { return }

                self.isMuted = $0.isZero
            }
            .store(in: &observations)
        isMuted = systemVolumeController.volume == 0

        engine.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self else { return }

                self.handleEngineEvent($0)
            }
            .store(in: &observations)

        fullscreenManager = FullscreenManager(playbackView: playbackView, containerView: containerView, eventHandler: { [weak self] in
            guard let self else { return }

            self.handleFullscreenEvent($0)
        })

        if let pluginSet {
            for plugin in pluginSet.createPlugins() {
                addPlugin(plugin)
            }
        }

        updateLayout()
    }

    private func updateLayout() {
        let containerView: UIView?

        if let fullscreenManager, fullscreenManager.isFullscreen, let fullscreenView = fullscreenManager.window?.viewController.view {
            containerView = fullscreenView

        } else {
            containerView = self.containerView
        }

        if let containerView {
            containerView.addSubview(playbackView)
            playbackView.frame = containerView.bounds
            playbackView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        } else {
            playbackView.removeFromSuperview()
        }

        if playbackView === engine.view {
            // Add control view to video view
            playbackView.addSubview(controlView)
            controlView.frame = playbackView.bounds
            controlView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        }
    }

    private func handleEngineEvent(_ event: EngineEvent) {
        switch event {
        case let .timeElapsed(currentTime):
            self.currentTime = currentTime

        case let .durationUpdated(duration):
            self.duration = duration

        case let .bufferedPositionUpdated(bufferedPosition):
            Logs.info("Buffered position: \(bufferedPosition)", tag: "Playback")
            self.bufferedPosition = bufferedPosition

        case let .stateChanged(playbackState):
            Logs.info("Playback state: \(playbackState)", tag: "Playback")
            self.playbackState = playbackState
        }
    }

    private func handleFullscreenEvent(_ event: FullscreenManager.Event) {
        switch event {
        case let .willEnter(rotationTransform):
            style = .fullscreen(rotationTransform)

        case .willExit:
            style = .inline

        default:
            break
        }
    }

    private func setSystemVolumeMuted(_ isMuted: Bool) {
        if isMuted {
            let currentVolume = systemVolumeController.volume
            systemVolumeController.recordVolume(currentVolume.isZero ? 0.5 : currentVolume)
            systemVolumeController.volume = 0

        } else {
            if !systemVolumeController.restoreRecordedVolume() {
                systemVolumeController.volume = 0.5
            }
        }
    }
}

//
//  AVPlaybackEngine.swift
//  Playback
//
//  Created by xueqooy on 2024/11/26.
//

import AVFoundation
import Combine
import XKit

public class AVPlaybackEngine: PlaybackEngine {
    public var url: URL? {
        get { _url }
        set {
            if let url = newValue {
                load(from: url, playWhenReady: playWhenReady, initialTime: nil)
            } else {
                _url = nil
                clearCurrentItem()
            }
        }
    }

    public var coverURL: URL?

    public var volume: Float {
        get { player.volume }
        set { player.volume = newValue }
    }

    public var isMuted: Bool {
        get { player.isMuted }
        set { player.isMuted = newValue }
    }

    public var rate: Float {
        get { _rate }
        set {
            _rate = newValue
            applyRate()
        }
    }

    public var playWhenReady: Bool = false {
        didSet {
            if playWhenReady == true && (state == .failed || state == .stopped) {
                reload(startFromCurrentTime: state == .failed)
            }

            applyRate()
        }
    }

    public var currentTime: TimeInterval {
        let seconds = player.currentTime().seconds
        return seconds.isNaN ? 0 : seconds
    }

    public var duration: TimeInterval {
        if let seconds = item?.asset.duration.seconds, !seconds.isNaN {
            return seconds
        } else if let seconds = item?.duration.seconds, !seconds.isNaN {
            return seconds
        } else if let seconds = item?.seekableTimeRanges.last?.timeRangeValue.duration.seconds,
                  !seconds.isNaN
        {
            return seconds
        }
        return 0.0
    }

    public var bufferedPosition: TimeInterval {
        item?.loadedTimeRanges.last?.timeRangeValue.end.seconds ?? 0
    }

    public private(set) var state: PlaybackState {
        get {
            stateQueue.sync { _state }
        }
        set {
            if let view {
                Queue.main.execute {
                    view.isCoverHidden = newValue != .idle && newValue != .loading && newValue != .ready
                }
            }

            stateQueue.execute(.asyncBarrier) { [weak self] in
                guard let self, self._state != newValue else { return }

                self._state = newValue
                self.eventSubject.send(.stateChanged(newValue))
            }
        }
    }

    public private(set) var view: VideoPresentable?

    public var eventPublisher: AnyPublisher<EngineEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    /// Set a view to display video
    public init(view: VideoPresentable? = nil) {
        self.view = view
        setupObserver()
        setupPlayer()
    }

    public func load(from url: URL, playWhenReady: Bool, initialTime: TimeInterval?) {
        self.playWhenReady = playWhenReady
        _url = url
        load()

        if let initialTime {
            seek(to: initialTime)
        }
    }

    public func play() {
        if state == .ended {
            // replay
            seek(to: 0)
        }

        playWhenReady = true
    }

    public func pause() {
        playWhenReady = false
    }

    public func stop() {
        state = .stopped
        clearCurrentItem()
        playWhenReady = false
    }

    public func seek(to seconds: TimeInterval) {
        if state == .ended {
            state = .paused
        }

        if player.currentItem == nil {
            timeToSeekAfterLoading = seconds
        } else {
            let time = CMTimeMakeWithSeconds(seconds, preferredTimescale: 1000)
            isSeeking = true
            player.seek(to: time, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero) { [weak self] _ in
                self?.isSeeking = false
            }
        }
    }

    public func seek(by seconds: TimeInterval) {
        if state == .ended {
            state = .paused
        }

        if let currentItem = player.currentItem {
            let time = currentItem.currentTime().seconds + seconds
            isSeeking = true
            player.seek(to: CMTimeMakeWithSeconds(time, preferredTimescale: 1000)) { [weak self] _ in
                self?.isSeeking = false
            }
        } else {
            if let timeToSeekAfterLoading = timeToSeekAfterLoading {
                self.timeToSeekAfterLoading = timeToSeekAfterLoading + seconds
            } else {
                timeToSeekAfterLoading = seconds
            }
        }
    }

    public func thumbnail(at time: TimeInterval, size: CGSize) async -> UIImage? {
        guard let imageGenerator else { return nil }
        imageGenerator.maximumSize = size

        return await withCheckedContinuation { continuation in
            let time = CMTimeMakeWithSeconds(time, preferredTimescale: 1000)
            imageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, image, _, _, _ in
                if let image {
                    continuation.resume(returning: UIImage(cgImage: image))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    // MARK: - Private

    private var eventSubject = PassthroughSubject<EngineEvent, Never>()

    private var player = AVPlayer()
    private let playerObserver = AVPlayerObserver()
    private var playerObservation: AnyCancellable?

    private var _url: URL?
    private var asset: AVURLAsset?
    private var item: AVPlayerItem?
    private let itemObserver = AVPlayerItemObserver()
    private var itemObservation: AnyCancellable?

    private var imageGenerator: AVAssetImageGenerator?

    private var _rate: Float = 1

    private var _state: PlaybackState = .idle
    private var stateQueue = Queue(label: "AVPlaybackEngine.StateQueue", isConcurrent: true)

    private var timeToSeekAfterLoading: TimeInterval?
    private var isSeeking = false

    private func applyRate() {
        let rate = playWhenReady ? _rate : 0
        if player.rate != rate {
            player.rate = rate
        }
    }

    private func setupObserver() {
        playerObservation = playerObserver.eventPublisher
            .sink { [weak self] event in
                guard let self else { return }

                switch event {
                case let .statusChanged(status):
                    if status == .failed {
                        if let error = self.item?.error {
                            Logs.error("Playback failed: \(error.localizedDescription)", tag: "Playback")
                        }

                        self.state = .failed
                    }

                case let .timeControlStatusChanged(status):
                    switch status {
                    case .paused:
                        let state = self.state
                        if self.asset == nil && state != .stopped {
                            self.state = .idle
                        } else if state != .failed && state != .stopped {
                            // Playback may have become paused externally for example due to a bluetooth device disconnecting:
                            if self.playWhenReady {
                                // Only if we are not on the boundaries of the track, otherwise itemDidPlayToEndTime will handle it instead.
                                if self.currentTime > 0 && self.currentTime < self.duration {
                                    self.playWhenReady = false
                                }
                            } else {
                                self.state = .paused
                            }
                        }

                    case .waitingToPlayAtSpecifiedRate:
                        if self.asset != nil {
                            self.state = .stalled
                        }

                    case .playing:
                        self.state = .playing

                    @unknown default:
                        break
                    }

                case .playbackStarted:
                    self.state = .playing

                case let .timeElapsed(time):
                    guard !self.isSeeking else { return }

                    self.eventSubject.send(.timeElapsed(time.seconds))
                }
            }

        itemObservation = itemObserver.eventPublisher
            .sink { [weak self] event in
                guard let self else { return }

                switch event {
                case let .durationUpdated(duration):
                    self.eventSubject.send(.durationUpdated(duration))

                case let .bufferredPositionUpdated(position):
                    self.eventSubject.send(.bufferedPositionUpdated(position))

                case let .presentationSizeUpdated(size):
                    view?.presentationSize = size

                case let .playbackLikelyToKeepUpUpdated(likelyToKeepUp):
                    if likelyToKeepUp && self.state == .loading {
                        self.state = .ready
                    }

                case .didPlayToEnd:
                    self.state = .ended

                case .failedToPlayToEndTime:
                    Logs.error("Playback failed: failed to play to end time", tag: "Playback")

                    self.state = .failed

                case .playbackStalled:
                    self.state = .stalled
                }
            }
    }

    private func setupPlayer() {
        if let view {
            let contentView = AVPlayerContentView(player: player)
            view.contentView = contentView
        }

        playerObserver.player = player

        applyRate()
    }

    private func load() {
        if state == .failed {
            recreatePlayer()
        } else {
            clearCurrentItem()
        }

        guard let url = _url else {
            return
        }

        let pendingAsset = AVURLAsset(url: url)
        asset = pendingAsset
        imageGenerator = AVAssetImageGenerator(asset: pendingAsset)
        state = .loading

        // Load playable portion of the track and commence when ready
        let keys = ["playable"]
        Task { @MainActor [weak self] in
            await pendingAsset.loadValues(forKeys: keys)

            guard let self, pendingAsset == self.asset else { return }

            for key in keys {
                var error: NSError?
                let keyStatus = pendingAsset.statusOfValue(forKey: key, error: &error)
                switch keyStatus {
                case .failed:
                    self.state = .failed
                    Logs.error("Playback failed: failed to load key value", tag: "Playback")
                    return
                case .cancelled, .loading, .unknown:
                    return
                case .loaded:
                    break
                default: break
                }
            }

            if !pendingAsset.isPlayable {
                Logs.error("Playback failed: item was unplayable", tag: "Playback")
                self.state = .failed
                return
            }

            let item = AVPlayerItem(asset: pendingAsset, automaticallyLoadedAssetKeys: keys)
            self.item = item
            self.player.replaceCurrentItem(with: item)
            self.itemObserver.item = item
            self.applyRate()

            if let initialTime = self.timeToSeekAfterLoading {
                self.timeToSeekAfterLoading = nil
                self.seek(to: initialTime)
            }
        }

        // Load custom cover image if needed
        if let view {
            if let coverURL {
                view.loadCoverImage(from: coverURL)
            } else {
                view.coverImage = nil
            }
        }
    }

    private func reload(startFromCurrentTime: Bool) {
        var time: TimeInterval? = nil
        if startFromCurrentTime {
            if let currentItem = item {
                if !currentItem.duration.isIndefinite {
                    time = currentItem.currentTime().seconds
                }
            }
        }
        load()
        if let time = time {
            seek(to: time)
        }
    }

    private func recreatePlayer() {
        playerObserver.player = nil
        itemObserver.item = nil

        clearCurrentItem()

        player = AVPlayer()
        setupPlayer()
    }

    private func clearCurrentItem() {
        guard let asset else { return }
        itemObserver.item = nil

        imageGenerator?.cancelAllCGImageGeneration()
        imageGenerator = nil

        asset.cancelLoading()
        self.asset = nil

        player.replaceCurrentItem(with: nil)
    }
}

// MARK: - AVPlayerContentView

private class AVPlayerContentView: UIView {
    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    init(player: AVPlayer) {
        super.init(frame: .zero)

        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspect
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - AVPlayerObserver

private class AVPlayerObserver {
    enum Event {
        case statusChanged(AVPlayer.Status)
        case timeControlStatusChanged(AVPlayer.TimeControlStatus)
        case playbackStarted
        case timeElapsed(CMTime)
    }

    weak var player: AVPlayer? {
        willSet {
            playerObservations.removeAll(keepingCapacity: true)

            guard let player else { return }

            if let boundaryTimeStartObservation {
                player.removeTimeObserver(boundaryTimeStartObservation)
                self.boundaryTimeStartObservation = nil
            }

            if let periodicTimeObservation {
                player.removeTimeObserver(periodicTimeObservation)
                self.periodicTimeObservation = nil
            }
        }
        didSet {
            maybeObservePlayer()
        }
    }

    var eventPublisher: AnyPublisher<Event, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    private let eventSubject = PassthroughSubject<Event, Never>()

    private var playerObservations = [AnyCancellable]()

    private var boundaryTimeStartObservation: Any?

    private var periodicTimeObservation: Any?

    private func maybeObservePlayer() {
        guard let player else { return }

        player.publisher(for: \.status, options: [.new, .initial])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self, self.player != nil else { return }

                self.eventSubject.send(.statusChanged($0))
            }
            .store(in: &playerObservations)

        player.publisher(for: \.timeControlStatus, options: .new)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self, self.player != nil else { return }

                self.eventSubject.send(.timeControlStatusChanged($0))
            }
            .store(in: &playerObservations)

        // The time to use as start boundary time. Cannot be zero.
        let startTime = NSValue(time: CMTime(value: 1, timescale: 1000))
        boundaryTimeStartObservation = player.addBoundaryTimeObserver(forTimes: [startTime], queue: nil) { [weak self] in
            guard let self, self.player != nil else { return }

            self.eventSubject.send(.playbackStarted)
        }

        // 0.5 second interval
        let interval = CMTime(value: 1, timescale: 2)
        periodicTimeObservation = player.addPeriodicTimeObserver(forInterval: interval, queue: nil) { [weak self] in
            guard let self, let item = self.player?.currentItem, !item.seekableTimeRanges.isEmpty else { return }

            self.eventSubject.send(.timeElapsed($0))
        }
    }
}

// MARK: - AVPlayerItemObserver

private class AVPlayerItemObserver {
    enum Event {
        case durationUpdated(TimeInterval)
        case bufferredPositionUpdated(TimeInterval)
        case presentationSizeUpdated(CGSize)
        case playbackLikelyToKeepUpUpdated(Bool)
        case didPlayToEnd
        case failedToPlayToEndTime
        case playbackStalled
    }

    weak var item: AVPlayerItem? {
        willSet {
            itemObservations.removeAll(keepingCapacity: true)
        }
        didSet {
            maybeObserveItem()
        }
    }

    var eventPublisher: AnyPublisher<Event, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    private let eventSubject = PassthroughSubject<Event, Never>()

    private var itemObservations = [AnyCancellable]()

    private func maybeObserveItem() {
        guard let item else { return }

        item.publisher(for: \.duration, options: .new)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self else { return }

                self.eventSubject.send(.durationUpdated($0.seconds))
            }
            .store(in: &itemObservations)

        item.publisher(for: \.loadedTimeRanges, options: .new)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self, let duration = $0.first?.timeRangeValue.duration.seconds else { return }

                self.eventSubject.send(.bufferredPositionUpdated(duration))
            }
            .store(in: &itemObservations)

        item.publisher(for: \.isPlaybackLikelyToKeepUp, options: .new)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self else { return }

                self.eventSubject.send(.playbackLikelyToKeepUpUpdated($0))
            }
            .store(in: &itemObservations)

        item.publisher(for: \.presentationSize, options: .new)
            .sink { [weak self] in
                guard let self else { return }

                self.eventSubject.send(.presentationSizeUpdated($0))
            }
            .store(in: &itemObservations)

        let notificationCenter = NotificationCenter.default

        notificationCenter.publisher(for: AVPlayerItem.didPlayToEndTimeNotification, object: item)
            .sink { [weak self] _ in
                guard let self else { return }

                self.eventSubject.send(.didPlayToEnd)
            }
            .store(in: &itemObservations)

        notificationCenter.publisher(for: AVPlayerItem.failedToPlayToEndTimeNotification, object: item)
            .sink { [weak self] _ in
                guard let self else { return }

                self.eventSubject.send(.failedToPlayToEndTime)
            }
            .store(in: &itemObservations)

        notificationCenter.publisher(for: AVPlayerItem.playbackStalledNotification, object: item)
            .sink { [weak self] _ in
                guard let self else { return }

                self.eventSubject.send(.playbackStalled)
            }
            .store(in: &itemObservations)
    }
}

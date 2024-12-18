//
//  VLCPlaybackEngine.swift
//  Playback
//
//  Created by xueqooy on 2024/11/27.
//

import Combine
import XKit
import MobileVLCKit

private let vlcVolumeMax: Float = 200
private let vlcVolumeMin: Float = 0

public class VLCPlaybackEngine: PlaybackEngine {
    public var url: URL? {
        get { _url }
        set {
            if let url = newValue {
                load(from: url, playWhenReady: playWhenReady, initialTime: nil)
            } else {
                _url = nil
                clearCurrentMedia()
            }
        }
    }

    public var coverURL: URL?

    public var volume: Float {
        get { Float(player.mediaPlayer.audio?.volume ?? 0) / vlcVolumeMax }
        set { player.mediaPlayer.audio?.volume = Int32(vlcVolumeMax * max(vlcVolumeMax, min(0, newValue))) }
    }

    public var isMuted: Bool {
        get { player.mediaPlayer.audio?.isMuted ?? false }
        set { player.mediaPlayer.audio?.isMuted = newValue }
    }

    public var rate: Float {
        get { player.mediaPlayer.rate }
        set { player.mediaPlayer.rate = newValue }
    }

    public var playWhenReady: Bool = false {
        didSet {
            if playWhenReady {
                switch state {
                case .ready, .paused, .stopped, .ended:
                    player.play()

                case .failed:
                    reload(startFromCurrentTime: true)

                default:
                    break
                }

            } else {
                player.pause()
            }
        }
    }

    public var currentTime: TimeInterval {
        player.mediaPlayer.time.seconds
    }

    public var duration: TimeInterval {
        media?.length.seconds ?? 0
    }

    public private(set) var bufferedPosition: TimeInterval = 0

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
        setupPlayer()
        setupObserver()
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
        playWhenReady = true
    }

    public func pause() {
        playWhenReady = false
    }

    public func stop() {
        state = .stopped
        clearCurrentMedia()
        playWhenReady = false
    }

    public func seek(to time: TimeInterval) {
        // Can't seek when stopped even if isSeekable is true
        if media != nil, player.mediaPlayer.isSeekable, state != .stopped {
            timeToSeekAfterPlaying = nil
            player.mediaPlayer.time = VLCTime(int: Int32(time * 1000))
        } else {
            timeToSeekAfterPlaying = time
        }
    }

    public func seek(by seconds: TimeInterval) {
        // Can't seek when stopped even if isSeekable is true
        if media != nil, player.mediaPlayer.isSeekable, state != .stopped {
            timeToSeekAfterPlaying = nil

            let time = currentTime + seconds
            player.mediaPlayer.time = VLCTime(int: Int32(time * 1000))
        } else {
            if let time = timeToSeekAfterPlaying {
                timeToSeekAfterPlaying = time + seconds
            } else {
                timeToSeekAfterPlaying = seconds
            }
        }
    }

    public func thumbnail(at time: TimeInterval, size: CGSize) async -> UIImage? {
        guard let mediaForThumbnail, duration > 0 else {
            return nil
        }

        return await Thumbnailer(media: mediaForThumbnail, size: size, position: Float(time / duration), cachePolicy: .none).getThumbnail()
    }

    // MARK: - Private

    private var eventSubject = PassthroughSubject<EngineEvent, Never>()

    private var player: VLCMediaListPlayer!
    private let playerObserver = VLCPlayerObserver()
    private var playerObservation: AnyCancellable?

    private var _url: URL?
    private var media: VLCMedia?
    private var mediaForThumbnail: VLCMedia?
    private var mediaObserver = VLCMediaObserver()
    private var mediaObservation: AnyCancellable?

    private var _state: PlaybackState = .idle
    private var stateQueue = Queue(label: "VLCPlaybackEngine.StateQueue", isConcurrent: true)

    private var timeToSeekAfterPlaying: TimeInterval?

    private func setupPlayer() {
        if let view {
            let contentView = VLCPlayerContentView()
            view.contentView = contentView

            player = VLCMediaListPlayer(drawable: contentView)
        } else {
            player = VLCMediaListPlayer()
        }

        playerObserver.player = player.mediaPlayer
    }

    private func setupObserver() {
        playerObservation = playerObserver.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self else { return }

                switch $0 {
                case let .stateChanged(state):
                    switch state {
                    case .playing:
                        // Hide cover image when playing
                        view?.coverImage = nil
                        self.state = .playing

                        if let timeToSeekAfterPlaying = self.timeToSeekAfterPlaying {
                            self.seek(to: timeToSeekAfterPlaying)
                        }

                    case .paused:
                        self.state = .paused

                    case .stopped:
                        self.state = .stopped

                    case .error:
                        self.state = .failed

                    case .buffering:
                        // FIXME: maybe vlc bug!!!, can't notify state from buffering to playing, Ignore buffering state
                        // self.state = .stalled
                        break

                    case .ended:
                        self.state = .ended

                    default: break
                    }

                case let .timeElapsed(currentTime):
                    self.eventSubject.send(.timeElapsed(currentTime))
                }
            }

        mediaObservation = mediaObserver.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self else { return }

                switch $0 {
                case .didFinishParsing:
                    if self.state == .loading {
                        self.state = .ready
                    }

                    if self.playWhenReady {
                        self.player.play()

                    } else {
                        self.player.pause()
                    }

                case let .durationUpdated(duration):
                    self.eventSubject.send(.durationUpdated(duration))

                case let .presentationSizeUpdated(size):
                    if let view {
                        view.presentationSize = size

                        maybeLoadDefaultCoverImage()
                    }
                }
            }
    }

    private func maybeLoadDefaultCoverImage(with presentationSize: CGSize? = nil) {
        guard view != nil, let mediaForThumbnail, coverURL == nil else { return }

        Task { [weak self] in
            guard let image = await Thumbnailer(media: mediaForThumbnail, size: presentationSize, cachePolicy: .readAndWrite).getThumbnail(), let self, self.state != .playing else {
                return
            }

            await MainActor.run {
                self.view?.coverImage = image
            }
        }
    }

    private func maybeLoadCustomCoverImage() {
        guard let view else { return }
        
        if let coverURL {
            view.loadCoverImage(from: coverURL)
        } else {
            view.coverImage = nil
        }
    }

    private func load() {
        guard let url = _url else {
            return
        }

        let media = VLCMedia(url: url)
        media.addOptions(["network-caching": 999])
        media.parse(options: [.parseNetwork])

        self.media = media
        mediaForThumbnail = VLCMedia(url: url)
        player.mediaList = VLCMediaList(array: [media])
        mediaObserver.media = media

        state = .loading

        maybeLoadCustomCoverImage()
    }

    private func reload(startFromCurrentTime: Bool) {
        var time: TimeInterval? = nil
        if startFromCurrentTime {
            if !currentTime.isInfinite {
                time = min(0, currentTime)
            }
        }
        load()
        if let time = time {
            seek(to: time)
        }
    }

    private func clearCurrentMedia() {
        state = .idle

        guard let media else { return }
        mediaObserver.media = nil

        media.delegate = nil
        media.parseStop()
        self.media = nil
        mediaForThumbnail = nil

        player.mediaList = VLCMediaList(array: [])
    }
}

private extension VLCTime {
    var seconds: TimeInterval {
        (value ?? NSNumber(value: 0)).doubleValue / 1000
    }
}

// MARK: - VLCPlayerContentView

private class VLCPlayerContentView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)

        isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - VLCPlayerObserver

class VLCPlayerObserver: NSObject, VLCMediaPlayerDelegate {
    enum Event: Equatable {
        case stateChanged(VLCMediaPlayerState)
        case timeElapsed(TimeInterval)
    }

    weak var player: VLCMediaPlayer? {
        willSet {
            playerObservations.removeAll(keepingCapacity: true)
        }
        didSet {
            maybeObservePlayer()
        }
    }

    var eventPublisher: AnyPublisher<Event, Never> {
        eventSubject
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    private let eventSubject = PassthroughSubject<Event, Never>()

    private var playerObservations = [AnyCancellable]()

    private func maybeObservePlayer() {
        guard let player else { return }

        player.delegate = self

        player.publisher(for: \.isPlaying)
            .sink { [weak self] isPlaying in
                guard let self, self.player != nil else { return }

                if isPlaying {
                    self.eventSubject.send(.stateChanged(.playing))
                }
            }
            .store(in: &playerObservations)
    }

    func mediaPlayerTimeChanged(_ aNotification: Notification) {
        guard let player = aNotification.object as? VLCMediaPlayer, player == self.player else { return }

        eventSubject.send(.timeElapsed(player.time.seconds))
    }

    func mediaPlayerStateChanged(_ aNotification: Notification) {
        guard let player = aNotification.object as? VLCMediaPlayer, player == self.player else { return }

        eventSubject.send(.stateChanged(player.state))
    }
}

// MARK: - VLCMediaObserver

class VLCMediaObserver: NSObject, VLCMediaDelegate {
    enum Event: Equatable {
        case didFinishParsing
        case durationUpdated(TimeInterval)
        case presentationSizeUpdated(CGSize)
    }

    weak var media: VLCMedia? {
        willSet {
            mediaObservations.removeAll(keepingCapacity: true)
        }
        didSet {
            maybeObserveMedia()
        }
    }

    var eventPublisher: AnyPublisher<Event, Never> {
        eventSubject
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    private let eventSubject = PassthroughSubject<Event, Never>()

    private var mediaObservations = [AnyCancellable]()

    private func maybeObserveMedia() {
        guard let media else { return }

        media.delegate = self

        media.publisher(for: \.length)
            .sink { [weak self] length in
                guard let self, self.media != nil else { return }

                self.eventSubject.send(.durationUpdated(length.seconds))
            }
            .store(in: &mediaObservations)
    }

    func mediaDidFinishParsing(_ aMedia: VLCMedia) {
        guard aMedia == media else { return }

        eventSubject.send(.didFinishParsing)

        var presentationSize: CGSize?

        for tracksInformation in aMedia.tracksInformation {
            guard let trackDict = tracksInformation as? [String: Any] else {
                continue
            }

            guard let type = trackDict[VLCMediaTracksInformationType] as? String, type == "video",
                  let width = trackDict[VLCMediaTracksInformationVideoWidth] as? CGFloat,
                  let height = trackDict[VLCMediaTracksInformationVideoHeight] as? CGFloat
            else {
                continue
            }

            presentationSize = CGSize(width: width, height: height)
        }

        if let presentationSize {
            eventSubject.send(.presentationSizeUpdated(presentationSize))
        }
    }
}

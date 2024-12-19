//
//  PlaybackEngine.swift
//  Playback
//
//  Created by xueqooy on 2024/11/26.
//

import Combine

public enum PlaybackState: Equatable {
    /// The url has not been set
    case idle
    /// The url has been set, but the media is not loaded yet
    case loading
    /// The media is loaded and ready to play, but not yet started, the previous state should be `loading`
    case ready
    case playing
    // The media is playing, but the playback is stalled, will resume when enough data is buffered
    case stalled
    case paused
    case failed
    case stopped
    case ended
    
    public var isPlayingOrStalled: Bool {
        self == .playing || self == .stalled
    }
}

public enum EngineEvent {
    case timeElapsed(TimeInterval)
    case durationUpdated(TimeInterval)
    case bufferedPositionUpdated(TimeInterval)
    case stateChanged(PlaybackState)
}

public protocol PlaybackEngine {
    var url: URL? { set get }

    // Uses the system volume
//    var volume: Float { get set }
//    var isMuted: Bool { get set }

    var coverURL: URL? { get set }

    var rate: Float { get set }

    var playWhenReady: Bool { get set }

    var currentTime: TimeInterval { get }

    var duration: TimeInterval { get }

    var bufferedPosition: TimeInterval { get }

    var state: PlaybackState { get }

    var view: VideoPresentable? { get }

    var eventPublisher: AnyPublisher<EngineEvent, Never> { get }

    func load(from url: URL, playWhenReady: Bool, initialTime: TimeInterval?)

    func play()

    func pause()

    func stop()

    func seek(to time: TimeInterval)

    func seek(by seconds: TimeInterval)

    func thumbnail(at time: TimeInterval, size: CGSize) async -> UIImage?
}

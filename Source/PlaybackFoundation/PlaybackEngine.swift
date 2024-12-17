//
//  PlaybackEngine.swift
//  Playback
//
//  Created by xueqooy on 2024/11/26.
//

import Combine

public enum PlaybackState: Equatable {
    case idle
    case loading
    case ready
    case playing
    case stalled
    case paused
    case failed
    case stopped
    case ended
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

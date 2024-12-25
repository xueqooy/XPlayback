//
//  PlaybackControllable.swift
//  Playback
//
//  Created by xueqooy on 2024/12/11.
//

import Combine
import Foundation
import PlaybackFoundation

public protocol PlaybackControllable: UIView {
    // Edge views
    var topView: UIView? { get }
    var bottomView: UIView? { get }
    var leftView: UIView? { get }
    var rightView: UIView? { get }

    var pendingTimeToSeekUpdatedPublisher: AnyPublisher<TimeInterval, Never> { get }
    var timeToSeekPublisher: AnyPublisher<TimeInterval, Never> { get }

    /// Attach the container to the controller.
    /// - warning: Controller should not be retained by the container.
    func attach(to player: HybridMediaPlayer)

    func startSeeking(with value: Float?)
    func endSeeking()
}

public extension PlaybackControllable {
    var topView: UIView? { nil }
    var bottomView: UIView? { nil }
    var leftView: UIView? { nil }
    var rightView: UIView? { nil }

    var allEdgeViews: [UIView] { [topView, bottomView, leftView, rightView].compactMap { $0 } }

    var pendingTimeToSeekUpdatedPublisher: AnyPublisher<TimeInterval, Never> {
        Empty().eraseToAnyPublisher()
    }

    var timeToSeekPublisher: AnyPublisher<TimeInterval, Never> {
        Empty().eraseToAnyPublisher()
    }

    func startSeeking(with _: Float?) {}
    func endSeeking() {}
}

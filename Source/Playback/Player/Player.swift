//
//  Player.swift
//  Playback
//
//  Created by xueqooy on 2022/12/21.
//

import UIKit
import Combine
import PlaybackFoundation

public protocol Player: AnyObject {
    /// Asset url
    var url: URL? { set get }
    /// Playback hint
    var hint: PlaybackHint? { set get }
    /// Video container view, should be weak reference. Set nil to remove from container view
    var containerView: UIView? { set get }
    
    var playbackStatePublisher: AnyPublisher<PlaybackState, Never> { get }
    var playbackState: PlaybackState { get }

    func play()
    func pause()
    func stop()
}

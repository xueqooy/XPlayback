//
//  PlaybackHint.swift
//  Playback
//
//  Created by xueqooy on 2024/12/2.
//

import Foundation

/// Provides information about hinting for the  video playback item (no effect for cache).
public struct PlaybackHint: Hashable {
    /// Decide which playback engine to use
    /// Use AVKit if format is included in `AVPlayerSupportedFormat`, otherwise use VLCKit
    public var format: String?
    /// Cover url of resource
    public var coverURL: URL?
    /// Probable Duration of video
    public var duration: TimeInterval?
    /// Time to seek to
    public var time: TimeInterval?
    /// Title of resource
    public var title: String?

    public init(format: String? = nil, coverURL: URL? = nil, duration: TimeInterval? = nil, time: TimeInterval? = nil, title: String? = nil) {
        self.format = format
        self.coverURL = coverURL
        self.duration = duration
        self.time = time
        self.title = title
    }
}

//
//  PlaybackItem.swift
//  Playback
//
//  Created by xueqooy on 2024/12/2.
//

import XKit
import UIKit

/**
 Identify a video playback item
 Identical playing content is distinguished by `tag`, for example, different cells in the list play the same video.
 */
public struct PlaybackItem: Hashable {
    public enum MediaType: String {
        case video
        case audio
    }
    
    public let mediaType: MediaType
    public let contentString: String
    public let tag: String

    public init(mediaType: MediaType, contentString: String, tag: String = UUID().uuidString) {
        self.mediaType = mediaType
        self.contentString = contentString
        self.tag = tag
    }
}

extension UIView {
    private static let videoPlaybackItemAssociation = Association<PlaybackItem>(wrap: .retain)

    /// Record the latest video playback item.
    var playbackItem: PlaybackItem? {
        set {
            Self.videoPlaybackItemAssociation[self] = newValue
        }
        get {
            Self.videoPlaybackItemAssociation[self]
        }
    }
}

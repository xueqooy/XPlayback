//
//  AudioResource.swift
//  Playback
//
//  Created by xueqooy on 2024/12/16.
//  Copyright © 2024 CocoaPods. All rights reserved.
//

import Foundation

protocol Resource: RawRepresentable, CaseIterable where RawValue == String {
    
    var contentString: String { get}
    
    var format: String? { get }
}

extension Resource {
    var contentString: String {
        switch self {
        case let value where value.rawValue.hasPrefix("local"):
            return Bundle.main.path(forResource: rawValue, ofType: format)!
      
        default:
            return rawValue
        }
    }
    
    var format: String? {
        switch self {
        case let value where value.rawValue.hasPrefix("local"):
            return value.rawValue.components(separatedBy: "_").last
            
        default:
            let components = rawValue.components(separatedBy: " ")
            if components.count == 2 {
                return components.last
            }
            
            return nil
        }
    }
    
    var isVideo: Bool {
        Self.self == VideoResource.self
    }
    
    var isAudio: Bool {
        Self.self == AudioResource.self
    }
}

enum AudioResource: String, Resource {
    case local_mp3
    case local_ogg
    case local_wav
}


enum VideoResource: String, Resource {
    case local_mp4
    case local_mov
    case local_wmv
    case local_vob
    case youtube = "https://www.youtube.com/embed/Xk4HZfW6vK0"
}

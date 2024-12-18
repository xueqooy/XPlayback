//
//  AVPlayerMediaFormat.swift
//  Pods
//
//  Created by xueqooy on 2024/12/16.
//

public enum AVPlayerSupportedFormat: String, CaseIterable {
    // Video
    case mp4, mov, m4v, mpg, _3gp

    // Audio
    case mp3, m4a, wav, aac, aif, aiff, caf, flac
    
    public var mimeTypes: [String] {
        switch self {
        case .mp4:
            ["video/mp4"]
        case .mov:
            ["video/quicktime"]
        case .m4v:
            ["video/x-m4v"]
        case .mpg:
            ["video/mpeg"]
        case ._3gp:
            ["video/3gpp"]
        case .mp3:
            ["audio/mpeg"]
        case .m4a:
            ["audio/mp4", "audio/x-m4a"]
        case .wav:
            ["audio/wav", "audio/x-wav", "audio/vnd.wave"]
        case .aac:
            ["audio/aac"]
        case .aif, .aiff:
            ["audio/x-aiff", "audio/aiff"]
        case .caf:
            ["audio/x-caf"]
        case .flac:
            ["audio/flac"]
        }
    }
    
    public static func contains(_ format: String) -> Bool {
        let matchFormat = allCases
            .lazy
            .map { $0.rawValue.lowercased() }
            .contains(format.lowercased())
        
        if matchFormat {
            return true
        }
        
        let matchMimeType = allCases
            .lazy
            .flatMap { $0.mimeTypes }
            .contains(format)
        
        return matchMimeType
    }
}

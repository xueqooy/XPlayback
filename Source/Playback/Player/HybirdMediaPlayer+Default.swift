//
//  HybirdMediaPlayer+Default.swift
//  Playback
//
//  Created by xueqooy on 2024/12/24.
//

import PlaybackFoundation

public enum BuiltInPlayerEngineType {
    case av
    case vlc
}

public extension HybridMediaPlayer {
    static func defaultVideoPlayer(engineType: BuiltInPlayerEngineType) -> HybridMediaPlayer {
        let videoView = DefaultVideoPresentationView()
        let controlView = DefaultVideoControlView()
        let pluginSet = DefaultVideoPlayerPlugins.all
        let engine: PlaybackEngine = switch engineType {
        case .av:
            AVPlaybackEngine(view: videoView)
        case .vlc:
            VLCPlaybackEngine(view: videoView)
        }
        let qualityMenuProvider = DefaultQualityMenuProvider()
        return HybridMediaPlayer(engine: engine, controlView: controlView, pluginSet: pluginSet, qualityMenuProvider: qualityMenuProvider)
    }

    static func defaultAudioPlayer(engineType: BuiltInPlayerEngineType) -> HybridMediaPlayer {
        let controlView = DefaultAudioControlView()
        let engine: PlaybackEngine = switch engineType {
        case .av:
            AVPlaybackEngine()
        case .vlc:
            VLCPlaybackEngine()
        }
        let qualityMenuProvider = DefaultQualityMenuProvider()
        return HybridMediaPlayer(engine: engine, controlView: controlView, qualityMenuProvider: qualityMenuProvider)
    }
}

//
//  DefaultVideoPlayerPlugins.swift
//  Playback
//
//  Created by xueqooy on 2024/12/12.
//

public struct DefaultVideoPlayerPlugins: OptionSet, PlayerPluginSet {
    public static let all: DefaultVideoPlayerPlugins = [longPressGesture, tapGesture, panGesture, seekingPreview]
    
    /// Long press to play fast forward
    public static let longPressGesture = DefaultVideoPlayerPlugins(rawValue: 1)
    /// Single tap to display/hide control, double tap to play/pause
    public static let tapGesture = DefaultVideoPlayerPlugins(rawValue: 1 << 1)
    /// Pan gesture to adjust volume, brightness and playback progress
    public static let panGesture = DefaultVideoPlayerPlugins(rawValue: 1 << 2)
    /// Show preview when seeking
    public static let seekingPreview = DefaultVideoPlayerPlugins(rawValue: 1 << 3)
    
    public var rawValue: UInt

    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    public func createPlugins() -> [PlayerPlugin] {
        var plugins: [PlayerPlugin] = []
        if contains(.longPressGesture) {
            plugins.append(LongPressGesturePlugin())
        }
        if contains(.tapGesture) {
            plugins.append(TapGesturePlugin())
        }
        if contains(.panGesture) {
            plugins.append(PanGesturePlugin())
        }
        if contains(.seekingPreview) {
            plugins.append(SeekingPreviewPlugin())
        }
        return plugins
    }
}

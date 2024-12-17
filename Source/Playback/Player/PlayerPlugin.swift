//
//  PlayerPlugin.swift
//  Playback
//
//  Created by xueqooy on 2024/12/3.
//

public protocol PlayerPlugin: AnyObject {
    /// Attach the plugin to the given controller.
    /// - warning: The plugin should not retain the controller.
    func attach(to player: HybridMediaPlayer)
    func detach()
}

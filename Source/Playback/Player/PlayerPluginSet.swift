//
//  PlayerPluginSet.swift
//  Playback
//
//  Created by xueqooy on 2024/12/12.
//

public protocol PlayerPluginSet {
    func createPlugins() -> [PlayerPlugin]
}

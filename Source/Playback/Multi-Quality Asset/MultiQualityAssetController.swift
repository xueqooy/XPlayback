//
//  MultiQualityAssetController.swift
//  Pods
//
//  Created by xueqooy on 2024/12/24.
//

import Combine
import XKit

public protocol QualityMenuProviding {
    var menuVisiblityPublisher: AnyPublisher<Bool, Never> { get }
    var isMenuVisible: Bool { get }

    func showMenu(from view: UIView, with items: [MultiQualityAsset.Item], currentIndex: Int, selectionHandler: @escaping (Int) -> Void)
    func hideMenu()

    init()
}

/// A structure representing a multi-quality asset with different quality items.
public struct MultiQualityAsset: Equatable {
    /// A structure representing a single quality item.
    public struct Item: Equatable {
        public let url: URL
        public let label: String
        public let shortLabel: String?

        public init(url: URL, label: String, shortLabel: String? = nil) {
            self.url = url
            self.label = label
            self.shortLabel = shortLabel
        }
    }

    public let items: [Item]
    public let defaultItem: Item

    public init(items: [Item], defaultIndex: Int = 0) {
        self.items = items
        defaultItem = items[defaultIndex]
    }
}

public class MultiQualityAssetController {
    public var menuVisibilityPublisher: AnyPublisher<Bool, Never> {
        menuProvider.menuVisiblityPublisher
    }

    public var isMenuVisible: Bool {
        menuProvider.isMenuVisible
    }

    @EquatableState
    public var asset: MultiQualityAsset? {
        didSet {
            menuProvider.hideMenu()
            currentItem = asset?.defaultItem

            if let currentItem {
                player?.url = currentItem.url
            }
        }
    }

    private let menuProvider: QualityMenuProviding
    private weak var player: HybridMediaPlayer?

    @EquatableState
    public var currentItem: MultiQualityAsset.Item?

    public init(menuProvider: QualityMenuProviding) {
        self.menuProvider = menuProvider
    }

    public func attach(to player: HybridMediaPlayer) {
        self.player = player

        if let currentItem {
            player.url = currentItem.url
        }
    }

    public func showMenu(from view: UIView) {
        guard let asset else { return }

        let index = asset.items.firstIndex(of: currentItem!) ?? 0
        menuProvider.showMenu(from: view, with: asset.items, currentIndex: index) { [weak self] index in
            guard let self else { return }

            self.playItem(at: index)
        }
    }

    public func playItem(at index: Int) {
        guard let asset, index >= 0, index < asset.items.count, let player else { return }

        currentItem = asset.items[index]

        let currentTime = player.currentTime
        let playWhenReady = player.playWhenReady
        player.load(from: currentItem!.url, playWhenReady: playWhenReady, initialTime: currentTime)
    }
}

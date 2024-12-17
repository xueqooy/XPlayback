//
//  PlayerCache.swift
//  Playback
//
//  Created by xueqooy on 2022/12/21.
//

import Combine
import Foundation
import XKit

/**
 Provide control layer cache and player cache.

 The players will be automatically removed  one by one at regular intervals, provided that the player is not placed in a container view, and the earliest player will be removed first.

 You can also call `.trim(single:)` manually to remove players.
 */
public class PlayerCache {
    private class Store {
        class Record: Hashable, CustomStringConvertible {
            let item: PlaybackItem
            let player: any Player
            var lastUseTime: TimeInterval?

            init(item: PlaybackItem, player: any Player) {
                self.item = item
                self.player = player
            }

            static func == (lhs: Record, rhs: Record) -> Bool {
                lhs.item == rhs.item
            }

            func hash(into hasher: inout Hasher) {
                hasher.combine(item)
            }

            var description: String {
                return "mediaType : \(item.mediaType), contentString : \(item.contentString), tag : \(item.tag), lastUseTime : \(String(describing: lastUseTime)))"
            }
        }

        private var recordForKey = [AnyHashable: Record]()
        private(set) var records = Set<Record>()

        private let lock = Lock()

        subscript(key: AnyHashable) -> Record? {
            set {
                lock.lock()
                if let newValue = newValue {
                    recordForKey[key] = newValue
                    records.update(with: newValue)
                } else {
                    if let oldValue = recordForKey[key] {
                        records.remove(oldValue)
                    }
                    recordForKey[key] = nil
                }
                lock.unlock()
            }
            get {
                let record: Record?
                lock.lock()
                record = recordForKey[key]
                lock.unlock()
                return record
            }
        }
    }

    public var players: [any Player] {
        store.records.map { $0.player }
    }

    public var autoTrimInterval: TimeInterval

    /// Callback after player being trimmed
    public var playerDidRemove: ((Player, PlaybackItem) -> Void)?

    private let store = Store()

    public init(autoTrimInterval: TimeInterval = 3) {
        self.autoTrimInterval = autoTrimInterval
        
        trimRecursively()

        NotificationCenter.default.addObserver(self, selector: #selector(appDidReceiveMemoryWarningNotification(_:)), name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
    }

    public func getPlayer(for item: PlaybackItem) -> (any Player)? {
        store[item]?.player
    }

    private static let numberOfCacheTrimTriggered = 8
    public func cachePlayer(_ player: any Player, for item: PlaybackItem) {
        let record = Store.Record(item: item, player: player)
        store[item] = record

        Logs.info("player has been cached -> \(record), current: \(store.records.count)", tag: "Playback")

        if players.count >= Self.numberOfCacheTrimTriggered {
            Queue.main.execute(.delay(1)) {
                self.trim(single: true)
            }
        }
    }

    public func removePlayer(for item: PlaybackItem) {
        store[item] = nil
    }

    public func bringUpToDate(_ item: PlaybackItem) {
        store[item]?.lastUseTime = CACurrentMediaTime()
    }

    private func trimRecursively() {
        Queue.concurrentBackground.execute(.delay(autoTrimInterval)) { [weak self] in
            guard let self = self else { return }
            self.trim(single: true)
            self.trimRecursively()
        }
    }

    /// Trim players witch has no container view
    public func trim(single: Bool) {
        Queue.main.execute {
            // The records which player without container view
            var recordsNeedToBeTrimmed = self.store.records.filter { record in
                guard let containerView = record.player.containerView else {
                    return true
                }

                return !containerView.isVisible(findsCell: true)
            }

            if single {
                let oldestRecord = recordsNeedToBeTrimmed.min {
                    ($0.lastUseTime ?? 0) < ($1.lastUseTime ?? 0)
                }

                if let oldestRecord = oldestRecord {
                    recordsNeedToBeTrimmed = [oldestRecord]
                } else {
                    recordsNeedToBeTrimmed = []
                }
            }

            for record in recordsNeedToBeTrimmed {
                self.store[record.item] = nil
                Logs.info("player has been trimmed -> \(record), current: \(self.store.records.count)", tag: "Playback")
            }

            for record in recordsNeedToBeTrimmed {
                self.playerDidRemove?(record.player, record.item)
            }
        }
    }

    @objc private func appDidReceiveMemoryWarningNotification(_: Notification) {
        Logs.warn("Did receive memory warning, will trim players", tag: "Playback")
        trim(single: false)
    }
}

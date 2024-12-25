//
//  PlaybackAssetManager.swift
//  Playback
//
//  Created by xueqooy on 2022/12/19.
//

import Foundation
import XKit

public enum PlaybackAsset: Equatable {
    // The resource displayed in web
    case embed(URL)

    // The local file resource
    case local(URL)

    // The network resource
    case network(URL)

    // The local file resource with multiple quality
    case localWithMultiQuality(MultiQualityAsset)

    // The network resource with multiple quality
    case networkWithMultiQuality(MultiQualityAsset)

    public var url: URL {
        switch self {
        case let .embed(url), let .local(url), let .network(url):
            return url
        case let .localWithMultiQuality(asset), let .networkWithMultiQuality(asset):
            return asset.defaultItem.url
        }
    }

    public var mutiQualityAsset: MultiQualityAsset? {
        switch self {
        case let .localWithMultiQuality(asset), let .networkWithMultiQuality(asset):
            return asset
        default:
            return nil
        }
    }

    public var isMultiQuality: Bool {
        switch self {
        case .localWithMultiQuality, .networkWithMultiQuality:
            return true
        default:
            return false
        }
    }
}

public struct PlaybackAssetResult {
    public let asset: PlaybackAsset
    public let expiredDate: Date?
    public let shouldCache: Bool

    public init(asset: PlaybackAsset, expiredDate: Date? = nil, shouldCache: Bool = true) {
        self.asset = asset
        self.expiredDate = expiredDate
        self.shouldCache = shouldCache
    }
}

public protocol PlaybackItemParseable {
    func parseItem(_ item: PlaybackItem) async -> PlaybackAssetResult?
}

/**
 Parse and memory cache resource URL.
 */
public class PlaybackAssetManager: NSObject {
    private class Cache {
        private let queue = Queue(label: "Playback.PlaybackAssetManager.Cache", isConcurrent: true)

        private var dictionary = [String: PlaybackAssetResult]()

        /// Return nil if url has expired
        func result(for item: PlaybackItem) -> PlaybackAssetResult? {
            queue.sync {
                let key = key(for: item)
                guard let result = dictionary[key] else {
                    return nil
                }

                if let expiredDate = result.expiredDate, Date().timeIntervalSince1970 >= expiredDate.timeIntervalSince1970 {
                    dictionary[key] = nil
                    return nil
                }

                return result
            }
        }

        func setResult(_ result: PlaybackAssetResult, for item: PlaybackItem) {
            queue.execute(.asyncBarrier) { [weak self] in
                guard let self else { return }

                dictionary[key(for: item)] = result
            }
        }

        func clear() {
            queue.execute(.asyncBarrier) { [weak self] in
                guard let self else { return }

                self.dictionary.removeAll()
            }
        }

        private func key(for item: PlaybackItem) -> String {
            item.mediaType.rawValue + "-" + item.contentString
        }
    }

    public static let shared = PlaybackAssetManager()

    /// Additional parsers for custom URL parsing
    public var additionalParsers: [PlaybackItemParseable] = [] {
        didSet {
            cache.clear()
        }
    }

    private let localFileParser = LocalFileAssetParser()
    private let embedParser = EmbedAssetParser()

    private let cache = Cache()

    public func parse(_ item: PlaybackItem) async -> PlaybackAssetResult? {
        // Read from cache first
        if let cachedResult = cache.result(for: item) {
            return cachedResult
        }

        // Parse local file URL
        if let result = await localFileParser.parseItem(item) {
            cache.setResult(result, for: item)
            return result
        }

        // Parse embed URL for video
        if item.mediaType == .video, let result = await embedParser.parseItem(item) {
            cache.setResult(result, for: item)
            return result
        }

        // Parse URL using additional parsers
        for parser in additionalParsers {
            if let result = await parser.parseItem(item) {
                cache.setResult(result, for: item)
                return result
            }
        }

        if let url = URL(string: item.contentString) {
            let result = PlaybackAssetResult(asset: .network(url))
            cache.setResult(result, for: item)
            return result
        }

        return nil
    }
}

// MARK: - LocalVideoAssetParser

class LocalFileAssetParser: PlaybackItemParseable {
    func parseItem(_ item: PlaybackItem) async -> PlaybackAssetResult? {
        let contentString = item.contentString
        if let url = URL(string: contentString), url.isFileURL {
            return PlaybackAssetResult(asset: .local(url))
        }

        if contentString.hasPrefix("/"), let url = URL(string: "file://\(contentString)") {
            return PlaybackAssetResult(asset: .local(url))
        }

        return nil
    }
}

// MARK: - EmbedAssetParser

class EmbedAssetParser: PlaybackItemParseable {
    func parseItem(_ item: PlaybackItem) async -> PlaybackAssetResult? {
        let contentString = item.contentString
        if let youtubeURL = parseYoutubeEmbed(from: contentString) {
            return PlaybackAssetResult(asset: .embed(youtubeURL), expiredDate: nil)
        }

        if let httpURL = parseHttpEmbed(from: contentString) {
            return PlaybackAssetResult(asset: .embed(httpURL), expiredDate: nil)
        }

        return nil
    }

    func parseYoutubeEmbed(from string: String) -> URL? {
        guard let url = URL(string: string),
              let host = url.host,
              host.contains("youtube") || host.contains("youtube")
        else {
            return nil
        }

        if let youtubeId = string.firstMatch(pattern: "((?<=(v|V)/)|(?<=be/)|(?<=(\\?|\\&)v=)|(?<=embed/))([\\w-]++)") {
            return URL(string: "https://www.youtube-nocookie.com/embed/\(youtubeId)?feature=player_detailpage&playsinline=1")
        }

        return nil
    }

    func parseHttpEmbed(from string: String) -> URL? {
        if let httpString = string.firstMatch(pattern: "\'http(.*?)\'") {
            return URL(string: httpString.replacingOccurrences(of: "\'", with: ""))
        }

        return nil
    }
}

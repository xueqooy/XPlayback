//
//  VideoURLParserManager.swift
//  Playback
//
//  Created by xueqooy on 2022/12/19.
//

import Foundation
import XKit

public enum PlaybackURLType {
    case embed // the resource displayed in web
    case file // the local file resource
    case network // the network resource
}

public struct PlaybackURLResult {
    public let url: URL
    public let type: PlaybackURLType
    public let expiredDate: Date?
    public let shouldCache: Bool
    
    public init(url: URL, type: PlaybackURLType, expiredDate: Date? = nil, shouldCache: Bool = true) {
        self.url = url
        self.type = type
        self.expiredDate = expiredDate
        self.shouldCache = shouldCache
    }
}

public protocol PlaybackItemParseable {
    func parseItem(_ item: PlaybackItem) async -> PlaybackURLResult?
}

/**
 Parse and memory cache resource URL.
 */
public class PlaybackURLManager: NSObject {
    private class Cache {
        private let queue = Queue(label: "Playback.PlaybackURLManager.Cache", isConcurrent: true)
        
        private var dictionary = [String: PlaybackURLResult]()

        /// Return nil if url has expired
        func result(for item: PlaybackItem) -> PlaybackURLResult? {
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

        func setResult(_ result: PlaybackURLResult, for item: PlaybackItem) {
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

    public static let shared = PlaybackURLManager()

    /// Additional parsers for custom URL parsing
    public var additionalParsers: [PlaybackItemParseable] = [] {
        didSet {
            cache.clear()
        }
    }

    private let fileParser = FileURLParser()
    private let embedParser = EmbedVideoURLParser()

    private let cache = Cache()

    public func parse(_ item: PlaybackItem) async -> PlaybackURLResult? {
        // Read from cache first
        if let cachedResult = cache.result(for: item) {
            return cachedResult
        }

        // Parse local file URL
        if let result = await fileParser.parseItem(item) {
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
            let result = PlaybackURLResult(url: url, type: .network)
            cache.setResult(result, for: item)
            return result
        }

        return nil
    }
}

// MARK: - LocalVideoURLParser

class FileURLParser: PlaybackItemParseable {
    func parseItem(_ item: PlaybackItem) async -> PlaybackURLResult? {
        let contentString = item.contentString
        if let url = URL(string: contentString), url.isFileURL {
            return PlaybackURLResult(url: url, type: .file, expiredDate: nil)
        }

        if contentString.hasPrefix("/"), let url = URL(string: "file://\(contentString)") {
            return PlaybackURLResult(url: url, type: .file, expiredDate: nil)
        }

        return nil
    }
}

// MARK: - EmbedURLParser

class EmbedVideoURLParser: PlaybackItemParseable {
    func parseItem(_ item: PlaybackItem) async -> PlaybackURLResult? {
        let contentString = item.contentString
        if let youtubeURL = parseYoutubeEmbed(from: contentString) {
            return PlaybackURLResult(url: youtubeURL, type: .embed, expiredDate: nil)
        }

        if let httpURL = parseHttpEmbed(from: contentString) {
            return PlaybackURLResult(url: httpURL, type: .embed, expiredDate: nil)
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

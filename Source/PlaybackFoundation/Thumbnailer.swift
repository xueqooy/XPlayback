//
//  Thumbnailer.swift
//  Playback
//
//  Created by xueqooy on 2022/12/15.
//

import Combine
import MobileVLCKit
import UIKit
import XKit

public actor Thumbnailer {
    public enum CachePolicy {
        case none
        case readAndWrite
    }

    private let url: URL?
    private var media: VLCMedia?
    private var size: CGSize?
    private let position: Float?
    private let cachePolicy: CachePolicy

    private var thumbnail: UIImage?

    private var vlcThumbnailer: VLCMediaThumbnailer?
    private var delegateProxy: ThumbnailerDelegateProxy?

    private var canStart: Bool = true

    private var continuations = [CheckedContinuation<UIImage?, Never>]()

    deinit {
        let continuations = self.continuations
        continuations.forEach { $0.resume(returning: nil) }
    }

    public init(media: VLCMedia, size: CGSize? = nil, position: Float? = nil, cachePolicy: CachePolicy = .none) {
        self.media = media
        url = media.url
        self.size = size
        self.position = position
        self.cachePolicy = cachePolicy
    }

    public init(url: URL, size: CGSize? = nil, position: Float? = nil, cachePolicy: CachePolicy = .none) {
        self.init(media: .init(url: url), size: size, position: position, cachePolicy: cachePolicy)
    }

    public func getThumbnail() async -> UIImage? {
        // Return if thumbnail is already loaded
        if let thumbnail {
            return thumbnail
        }

        // Return cached thumbnail
        if cachePolicy == .readAndWrite, let url, let thumbnail = ThumbnailCache.shared.getThumbnail(for: .init(url: url, size: size, position: position)) {
            self.thumbnail = thumbnail
            return thumbnail
        }

        maybeSetup()

        guard let vlcThumbnailer else {
            return nil
        }

        if canStart {
            canStart = false
            vlcThumbnailer.fetchThumbnail()
        }

        return await withCheckedContinuation { continuation in
            self.continuations.append(continuation)
        }
    }

    private func maybeSetup() {
        guard vlcThumbnailer == nil, let media else {
            return
        }

        let delegateProxy = ThumbnailerDelegateProxy()
        self.delegateProxy = delegateProxy

        let vlcThumbnailer = VLCMediaThumbnailer(media: media, andDelegate: delegateProxy)
        if let size {
            vlcThumbnailer.thumbnailWidth = size.width
            vlcThumbnailer.thumbnailHeight = size.height
        }
        if let position {
            vlcThumbnailer.snapshotPosition = position
        }
        self.vlcThumbnailer = vlcThumbnailer

        delegateProxy.finished = { [weak self] image in
            Task {
                guard let self else { return }

                try await self.thumbnailDidLoad(image)
            }
        }

        delegateProxy.timedOut = { [weak self] in
            Task {
                guard let self else { return }

                await self.timeDidOut()
            }
        }
    }

    private func thumbnailDidLoad(_ thumbnail: UIImage) async throws {
        let continuations = self.continuations
        self.continuations.removeAll()
        continuations.forEach { $0.resume(returning: thumbnail) }

        vlcThumbnailer = nil
        delegateProxy = nil
        media = nil

        try Task.checkCancellation()

        self.thumbnail = thumbnail
        if cachePolicy == .readAndWrite, let url {
            let parameters = ThumbnailCache.Parameters(url: url, size: size, position: position)

            Queue.concurrentBackground.execute {
                ThumbnailCache.shared.saveThumbnail(thumbnail, for: parameters)
            }
        }
    }

    private func timeDidOut() async {
        let continuations = self.continuations
        self.continuations.removeAll()
        continuations.forEach { $0.resume(returning: nil) }

        canStart = true
    }
}

private class ThumbnailerDelegateProxy: NSObject, VLCMediaThumbnailerDelegate {
    var finished: ((UIImage) -> Void)?
    var timedOut: (() -> Void)?

    func mediaThumbnailerDidTimeOut(_: VLCMediaThumbnailer) {
        timedOut?()
    }

    func mediaThumbnailer(_: VLCMediaThumbnailer, didFinishThumbnail thumbnail: CGImage) {
        if let finished {
            finished(UIImage(cgImage: thumbnail))
        }
    }
}

private class ThumbnailCache {
    struct Parameters {
        let url: URL
        let size: CGSize?
        let position: Float?
    }

    public static let shared = ThumbnailCache()

    private let thumbnailDirectory: String = {
        let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0] as NSString
        let thumbnailDirectory = paths.appendingPathComponent("thumbnail")
        return thumbnailDirectory.removingPercentEncoding!
    }()

    func path(for parameters: Parameters) -> String {
        var filename: String
        let url = parameters.url

        if url.isFileURL {
            filename = url.pathComponents.suffix(2).joined(separator: "/").sha1Encoded()
        } else {
            filename = url.absoluteString.sha1Encoded()
        }

        if let size = parameters.size {
            filename += "_\(size.width)x\(size.height)"
        }

        if let position = parameters.position {
            filename += "_\(String(format: "%.3f", position))"
        }

        return String(format: "%@/%@.%@", thumbnailDirectory, filename, "png")
    }

    func getThumbnail(for parameters: Parameters) -> UIImage? {
        let thumbnailPath = path(for: parameters)

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: thumbnailPath) {
            let url = URL(fileURLWithPath: thumbnailPath)

            return UIImage(contentsOfFile: url.path)
        }
        return nil
    }

    func removeThumbnail(for parameters: Parameters) {
        let thumbnailPath = path(for: parameters)

        let fileManager = FileManager.default
        var isDir = ObjCBool(false)
        if fileManager.fileExists(atPath: thumbnailPath, isDirectory: &isDir) {
            do {
                try fileManager.removeItem(atPath: thumbnailPath as String)
            } catch let error as NSError {
                Logs.error("error remove : \(error)", tag: "Playback")
            }
        }
    }

    @discardableResult
    func saveThumbnail(_ thumbnail: UIImage, for parameters: Parameters) -> URL? {
        let imageData = thumbnail.pngData()

        let pngSize: Int = imageData?.count ?? 0
        if pngSize > getFreeDiskSpace() ?? 0 {
            return nil
        }

        let thumbnailDir = thumbnailDirectory
        let thumbnailPath = path(for: parameters)
        var errorOccured = false

        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: thumbnailDir) {
            do {
                try fileManager.createDirectory(atPath: thumbnailDir, withIntermediateDirectories: true, attributes: nil)
            } catch let error as NSError {
                errorOccured = true
                Logs.error("error creating directory: \(error)", tag: "Playback")
            }
        }
        if !fileManager.fileExists(atPath: thumbnailPath as String) {
            do {
                try imageData?.write(to: URL(fileURLWithPath: thumbnailPath, relativeTo: nil))
            } catch let error as NSError {
                errorOccured = true
                Logs.error("error writing thumbnail : \(error)", tag: "Playback")
            }
        }

        return errorOccured ? nil : URL(fileURLWithPath: thumbnailPath, relativeTo: nil)
    }

    private func getFreeDiskSpace() -> Int? {
        let fileURL = URL(fileURLWithPath: "/")
        do {
            let values = try fileURL.resourceValues(forKeys: [.volumeAvailableCapacityKey])
            if let capacity = values.volumeAvailableCapacity {
                return capacity
            } else {
                Logs.warn("Capacity is unavailable", tag: "Playback")
            }
        } catch {
            Logs.error("Error retrieving capacity", tag: "Playback")
        }
        return nil
    }
}

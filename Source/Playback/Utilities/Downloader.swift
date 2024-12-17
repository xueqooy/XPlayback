//
//  Downloader.swift
//  Playback
//
//  Created by xueqooy on 2022/12/15.
//

import Foundation
import XKit

enum DownloadError: Error {
    case cancelled
    case unknown(source: Error)
}

struct DownloadItem {
    let url: URL
    let headers: [String: String]?

    fileprivate let filename: String

    init(url: URL, headers: [String: String]? = nil) {
        self.url = url
        self.headers = headers
        filename = (url.absoluteString + (headers?.description ?? "")).sha1Encoded()
    }
}

/**
 Download file to specifield directory (/Documents/[name]/[filename]).
 */
class Downloader: NSObject {
    private class TaskWrapper {
        let task: URLSessionTask
        let fileURL: URL
        var continuation: CheckedContinuation<URL, Error>?

        init(task: URLSessionTask, fileURL: URL) {
            self.task = task
            self.fileURL = fileURL
        }

        func cancel() {
            task.cancel()

            resume(with: .cancelled)
        }

        func resume(with error: DownloadError? = nil) {
            guard let continuation else { return }
            self.continuation = nil

            Once.execute(task.taskDescription ?? UUID().uuidString) {
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: fileURL)
                }
            }
        }
    }

    static let `default` = Downloader(name: "default")

    let name: String
    var directoryPath: String {
        let directory = rootDirectoryPath
        return (directory as NSString).appendingPathComponent(name)
    }

    private let rootDirectoryPath: String = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0]

    private var urlSession: URLSession!

    private var taskWrapperMap: [UUID: TaskWrapper] = [:]

    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier?

    init(name: String) {
        self.name = name

        super.init()

        urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }

    deinit {
        terminateBackgroundTask()

        cancelDownload()
    }

    @discardableResult
    func download(_ item: DownloadItem, readFromCache: Bool = true) async throws -> URL {
        let fileURL = fileURL(for: item)

        // read from cache
        if readFromCache {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                return fileURL
            }
        }

        beginBackgroundTask()

        let urlRequest = createURLRequest(for: item)
        let identifier = UUID()

        let task = urlSession.downloadTask(with: urlRequest)
        task.taskDescription = identifier.uuidString

        let taskWrapper = TaskWrapper(task: task, fileURL: fileURL)
        taskWrapperMap[identifier] = taskWrapper

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                taskWrapper.continuation = continuation

                task.resume()
            }
        } onCancel: {
            taskWrapper.cancel()
        }
    }

    // MARK: Private

    private func createURLRequest(for item: DownloadItem) -> URLRequest {
        var urlRequest = URLRequest(url: item.url)

        if let headers = item.headers {
            for (key, value) in headers {
                urlRequest.addValue(value, forHTTPHeaderField: key)
            }
        }

        return urlRequest
    }

    private func fileURL(for item: DownloadItem) -> URL {
        NSURL(fileURLWithPath: (directoryPath as NSString).appendingPathComponent(item.filename)) as URL
    }

    private func cancelDownload() {
        let fileManager = FileManager.default

        let taskWrapperMap = self.taskWrapperMap
        self.taskWrapperMap.removeAll()

        for (_, taskWrapper) in taskWrapperMap {
            taskWrapper.cancel()
        }
    }
}

extension Downloader: URLSessionDownloadDelegate {
    func urlSession(_: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let taskDescription = downloadTask.taskDescription,
              let identifier = UUID(uuidString: taskDescription),
              let taskWrapper = taskWrapperMap[identifier]
        else {
            return
        }

        let fileManager = FileManager.default
        var fileURL = taskWrapper.fileURL

        // Create directory if needed
        if !fileManager.fileExists(atPath: directoryPath) {
            try? fileManager.createDirectory(atPath: directoryPath, withIntermediateDirectories: true, attributes: nil)
        }

        if !fileManager.fileExists(atPath: fileURL.path) {
            try? fileManager.copyItem(at: location, to: fileURL)
        }
    }

    func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let taskDescription = task.taskDescription,
              let identifier = UUID(uuidString: taskDescription),
              let taskWrapper = taskWrapperMap[identifier]
        else {
            return
        }

        taskWrapperMap.removeValue(forKey: identifier)

        if let error = error {
            if (error as NSError).code != NSURLErrorCancelled {
                taskWrapper.resume(with: .unknown(source: error))

            } else {
                taskWrapper.resume(with: .cancelled)
            }
        } else {
            taskWrapper.resume()
        }
    }
}

// MARK: - background task management

private extension Downloader {
    func beginBackgroundTask() {
        if backgroundTaskIdentifier == nil || backgroundTaskIdentifier == .invalid {
            let expirationHandler = { [weak self] in
                guard let self = self else { return }

                Logs.info("Cancelling active download because the expiration date was reached, time remaining: \(UIApplication.shared.backgroundTimeRemaining)", tag: "Playback")
                self.cancelDownload()
                if let backgroundTaskIdentifier = self.backgroundTaskIdentifier {
                    UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
                }
                self.backgroundTaskIdentifier = .invalid
            }
            backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "Playback.Downloader.BackgroundTask", expirationHandler: expirationHandler)
        }
    }

    func terminateBackgroundTask() {
        if let backgroundTaskIdentifier = backgroundTaskIdentifier, backgroundTaskIdentifier != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
            self.backgroundTaskIdentifier = .invalid
        }
    }
}

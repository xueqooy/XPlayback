//
//  EmbedVideoPlayer.swift
//  Playback
//
//  Created by xueqooy on 2022/12/20.
//

import Foundation
import XKit
import WebKit
import PlaybackFoundation
import Combine

/// Play embed video, e.g. youtube
public class EmbedVideoPlayer: NSObject, Player {
    private enum Tool {
        static let iframeId = "EmbedVideoPlayer.youtube.iframe"

        static let playingMessageName = "playing"
        static let pauseMessageName = "pause"
        static let endedMessageName = "ended"

        static func generateYoutubeHTML(urlString: String) -> String {
            """
                <iframe id=\"\(iframeId)\" width=\"100%%\" height=\"100%%\" src=\"\(urlString)\" frameborder=\"0\" allow=\"autoplay; encrypted-media\"  allowfullscreen> </iframe>
            """
        }

        static func generateElementsTraversalScript(
            by: String, name: String, action: (String) -> String
        ) -> String {
            """
                var context = document;
                var iframe = context.getElementById(\'\(iframeId)\');
                if (iframe) {
                    context = iframe.contentWindow.document;
                }
                var elements = context.getElementsBy\(by)('\(name)');
                for( var i = 0; i < elements.length; i++ ){
                    \(action("elements.item(i)"))
                }
            """
        }

        static func generateVideoScript(action: (String) -> String) -> String {
            """
                var context = document;
                var iframe = context.getElementById(\'\(iframeId)\');
                if (iframe) {
                    context = iframe.contentWindow.document;
                }
                var elements = context.getElementsByTagName('video');
                \(action("elements.item(0)"))
            """
        }

        static func isYoutubeEmbedURL(_ urlString: String) -> Bool {
            urlString.firstMatch(
                pattern:
                "(?:youtu\\.be\\/|youtube(?:-nocookie)?\\.com(?:\\/embed\\/|\\/v\\/|\\/watch\\?v=|\\/ytscreeningroom\\?v=\n"
                    + "|\\/feeds\\/api\\/videos\\/|\\/user\\S*[^\\w\\-\\s]|\\S*[^\\w\\-\\s]))([\\w\\-]{11})[?=&+%\\w-]*"
            )?.contains("embed") ?? false
        }
    }

    public var url: URL? {
        didSet {
            if url == nil {
                playbackState = .idle
                webView.isHidden = true
            } else if oldValue != url {
                playbackState = .loading
                load()
            }
        }
    }

    public var hint: PlaybackHint?

    public var playbackStatePublisher: AnyPublisher<PlaybackState, Never> {
        $playbackState.didChange
    }
    
    @EquatableState
    public private(set) var playbackState: PlaybackState = .idle {
        didSet {
            guard oldValue != playbackState else { return }
            
            Logs.info("Embed Video playback state: \(playbackState)", tag: "Playback")
        }
    }

    // Video container view
    public weak var containerView: UIView? {
        didSet {
            guard let containerView = containerView else {
                webView.removeFromSuperview()
                return
            }

            containerView.addSubview(webView)
            webView.frame = containerView.bounds
            webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        }
    }

    private lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.userContentController.add(messageHandler, name: Tool.playingMessageName)
        configuration.userContentController.add(messageHandler, name: Tool.pauseMessageName)
        configuration.userContentController.add(messageHandler, name: Tool.endedMessageName)
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = self

        return webView
    }()

    private lazy var messageHandler: WebMessageHandler = {
        let messageHandler = WebMessageHandler()
        messageHandler.messageReceived = { [weak self] message in
            guard let self else {
                return
            }
            switch message.name {
            case Tool.playingMessageName:
                self.playbackState = .playing
            case Tool.pauseMessageName:
                if self.playbackState != .stopped {
                    self.playbackState = .paused
                }
            case Tool.endedMessageName:
                self.playbackState = .ended
            default: break
            }
        }
        return messageHandler
    }()

    private func load() {
        guard let url = url else { return }

        let urlString = url.absoluteString

        if Tool.isYoutubeEmbedURL(urlString) {
            // Load youtube embed
            let html = Tool.generateYoutubeHTML(urlString: urlString)

            if let host = url.host, let scheme = url.scheme,
               let baseURL = URL(string: "\(scheme)://\(host)")
            {
                webView.loadHTMLString(html, baseURL: baseURL)
                return
            }
        }

        // Load request
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 30)
        webView.load(request)
    }

    public func play() {
        let script = Tool.generateVideoScript { video in
            "\(video).play()"
        }
        webView.evaluateJavaScript(script)
    }

    public func pause() {
        let script = Tool.generateVideoScript { video in
            "\(video).pause()"
        }
        webView.evaluateJavaScript(script)
    }

    public func stop() {
        playbackState = .stopped
        let script = Tool.generateVideoScript { video in
            """
            \(video).pause();
            \(video).currentTime = 0;
            """
        }
    }
    
    public func enterFullscreen() {
        let script = Tool.generateVideoScript { video in
            "\(video).webkitEnterFullscreen()"
        }
        webView.evaluateJavaScript(script)
    }
    
    public func exitFullscreen() {
        let script = Tool.generateVideoScript { video in
            "\(video).webkitExitFullscreen()"
        }
        webView.evaluateJavaScript(script)
    }
}

extension EmbedVideoPlayer: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
        // Remove some youtube elements
        let removalAction = { (item: String) -> String in
            "\(item).parentNode.removeChild(\(item)"
        }
        let removedClassNames = [
            "ytp-gradient-top", "ytp-chrome-top", "ytp-show-cards-title", "ytp-pause-overlay",
        ]
        removedClassNames.map { name in
            Tool.generateElementsTraversalScript(by: "ClassName", name: name, action: removalAction)
        }.forEach { script in
            webView.evaluateJavaScript(script)
        }

        // Add playback state event listeners
        let videoPlaybackStateMessages = [
            Tool.playingMessageName, Tool.pauseMessageName, Tool.endedMessageName,
        ]
        let addVideoPlaybackStateListenerScript = Tool.generateVideoScript { video in
            videoPlaybackStateMessages.reduce(into: "") { partialResult, message in
                partialResult += """
                    \(video).addEventListener('\(message)', function(){
                        window.webkit.messageHandlers.\(message).postMessage('\(message)')
                    });
                """
            }
        }
        webView.evaluateJavaScript(addVideoPlaybackStateListenerScript)

        webView.isHidden = false
        playbackState = .ready
    }

    public func webView(
        _ webView: WKWebView, didFail _: WKNavigation!, withError _: Error
    ) {
        webView.isHidden = true
    }
}

private class WebMessageHandler: NSObject, WKScriptMessageHandler {
    var messageReceived: ((WKScriptMessage) -> Void)?

    func userContentController(
        _: WKUserContentController, didReceive message: WKScriptMessage
    ) {
        messageReceived?(message)
    }
}

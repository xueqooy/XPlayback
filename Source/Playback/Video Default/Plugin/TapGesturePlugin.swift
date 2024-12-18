//
//  TapGestureManager.swift
//  Playback
//
//  Created by xueqooy on 2024/12/2.
//

import Combine
import XUI
import XKit
import UIKit

public class TapGesturePlugin: NSObject, PlayerPlugin {
    private var isControlDisplaying: Bool {
        controlView?.allEdgeViews.contains {
            $0.alpha != 0
        } ?? false
    }

    private var isStartVideoButtonHidden: Bool {
        startVideoButton.isHidden
    }
    
    private lazy var startVideoButton = Button(image: Assets.image(named: "play.circle"))
    private lazy var tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(Self.tapGestureAction))
    private lazy var doubleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(Self.doubleTapGestureAction))
    private var autoHideTimer: XKit.Timer?

    private weak var player: HybridMediaPlayer?
    private weak var controlView: PlaybackControllable?
    private var observations = [AnyCancellable]()

    public override init() {
        super.init()
        
        doubleTapGestureRecognizer.numberOfTapsRequired = 2
        // Add a double tap gesture on the cell and set delaysTouchesBegan to true to give the gesture a chance to be responded to
        doubleTapGestureRecognizer.delaysTouchesBegan = true
        doubleTapGestureRecognizer.delegate = self
        tapGestureRecognizer.require(toFail: doubleTapGestureRecognizer)

        startVideoButton.touchUpInsideAction = { [weak self] _ in
            self?.playInFullscreen()
        }
        
    }
    
    public func attach(to player: HybridMediaPlayer) {
        detach()
        
        let controlView = player.controlView
        
        self.player = player
        self.controlView = controlView

        controlView.addGestureRecognizer(doubleTapGestureRecognizer)
        controlView.addGestureRecognizer(tapGestureRecognizer)
        controlView.addSubview(startVideoButton)
        controlView.pendingTimeToSeekUpdatedPublisher
            .sink { [weak self] _ in
                guard let self else { return }

                // Show controls when seeking
                self.showViewsIfPossible()
                self.stopAutoHideTimer()
            }
            .store(in: &observations)

        controlView.timeToSeekPublisher
            .sink { [weak self] _ in
                guard let self, let player = self.player else { return }
                if player.playbackState == .playing {
                    self.startAutoHideTimer()
                }
            }
            .store(in: &observations)

        player.$playbackState.didChange
            .sink { [weak self] in
                guard let self else { return }

                // Show start view button when playback state is idle or ready, otherwise hide it and show controls

                switch $0 {
                case .idle, .loading, .ready:
                    if self.player?.style.isFullscreen == false {
                        self.startVideoButton.isHidden = false
                    }
                    self.doubleTapGestureRecognizer.isEnabled = false
                    self.hideViews(animated: false)

                case .playing:
                    self.startVideoButton.isHidden = true
                    self.doubleTapGestureRecognizer.isEnabled = true
                    self.startAutoHideTimer()

                default:
                    self.startVideoButton.isHidden = true
                    self.doubleTapGestureRecognizer.isEnabled = true
                    self.stopAutoHideTimer()
                    self.showViews()
                }
            }
            .store(in: &observations)

        player.$style.didChange
            .sink { [weak self] _ in
                guard let self else { return }

                self.updateFullscreenPlayButtonLayout()
            }
            .store(in: &observations)
    }
    
    public func detach() {
        stopAutoHideTimer()
        observations.removeAll(keepingCapacity: true)
        startVideoButton.removeFromSuperview()
        
        if let controlView {
            controlView.removeGestureRecognizer(doubleTapGestureRecognizer)
            controlView.removeGestureRecognizer(tapGestureRecognizer)
            controlView.allEdgeViews.forEach { $0.alpha = 1 }
        }
    
        controlView = nil
        player = nil
    }

    private func updateFullscreenPlayButtonLayout() {
        guard let player else { return }

        startVideoButton.snp.remakeConstraints { make in
            make.size.equalTo(CGSize.square(34))

            if player.style.isFullscreen {
                make.center.equalToSuperview()
            } else {
                make.left.bottom.equalToSuperview().inset(CGFloat.XUI.spacing3)
            }
        }
    }

    private func maybeRestartAutoHideTimer() {
        guard autoHideTimer?.isRunning == true else { return }

        startAutoHideTimer()
    }

    private func startAutoHideTimer() {
        autoHideTimer = .init(interval: 4.0) { [weak self] in
            guard let self else { return }

            self.hideViews()
        }

        autoHideTimer?.start()
    }

    private func stopAutoHideTimer() {
        guard let autoHideTimer else { return }

        autoHideTimer.stop()
        self.autoHideTimer = nil
    }

    private func showViewsIfPossible() {
        guard isStartVideoButtonHidden else { return }

        showViews()
    }

    private func showViews(animated: Bool = true) {
        startVideoButton.isHidden = true

        var changed = false

        for view in controlView?.allEdgeViews ?? [] {
            if view.alpha == 0 {
                view.alpha = 1

                if animated {
                    view.layer.animateAlpha(from: 0, to: 1, duration: 0.25)
                }

                changed = true
            }
        }
        
        if let player, changed {
            player.shouldHideStatusBarForFullscreen = false
        }
    }

    private func hideViews(animated: Bool = true) {
        stopAutoHideTimer()

        var changed = false
        
        for view in controlView?.allEdgeViews ?? [] {
            if view.alpha == 1 {
                view.alpha = 0

                if animated {
                    view.layer.animateAlpha(from: 1, to: 0, duration: 0.25)
                }

                changed = true
            }
        }

        if let player, changed {
            player.shouldHideStatusBarForFullscreen = true
        }
    }

    @objc private func tapGestureAction(_ sender: UITapGestureRecognizer) {
        guard let controlView else { return }

        if !isStartVideoButtonHidden {
            playInFullscreen()
        } else if isControlDisplaying {
            // If the tap is on the edge view, do nothing
            for view in controlView.allEdgeViews {
                let location = sender.location(in: view)
                if view.bounds.contains(location) {
                    return
                }
            }

            hideViews()
        } else {
            showViews()
        }
    }

    @objc private func doubleTapGestureAction(_: UITapGestureRecognizer) {
        guard let player, player.playbackState != .idle else { return }

        if player.playbackState == .playing {
            player.pause()
        } else {
            player.play()
        }
    }

    private func playInFullscreen() {
        guard let player else { return }

        showViews()

        player.enterFullscreen()
        player.play()
    }
}

extension TapGesturePlugin: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let controlView, gestureRecognizer === doubleTapGestureRecognizer else { return false }

        if isStartVideoButtonHidden {
            if isControlDisplaying {
                // If the double tap is on the edge view, do nothing
                for view in controlView.allEdgeViews {
                    let location = touch.location(in: view)
                    if view.bounds.contains(location) {
                        return false
                    }
                }
            }

        } else if gestureRecognizer !== tapGestureRecognizer {
            return false
        }

        return true
    }
}

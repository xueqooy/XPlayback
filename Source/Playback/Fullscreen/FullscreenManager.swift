//
//  FullscreenManager.swift
//  Playback
//
//  Created by xueqooy on 2024/12/3.
//

import Combine
import UIKit
import XKit
import XUI

public enum RotationTransform {
    case none
    case left
    case right
    case upsideDown

    var isLandscape: Bool {
        self == .left || self == .right
    }

    init(orientation: UIInterfaceOrientation) {
        switch orientation {
        case .landscapeLeft:
            self = .left
        case .landscapeRight:
            self = .right
        case .portraitUpsideDown:
            self = .upsideDown
        default:
            self = .none
        }
    }

    var transform: CGAffineTransform {
        switch self {
        case .none:
            return .identity
        case .left:
            return CGAffineTransform(rotationAngle: -.pi / 2)
        case .right:
            return CGAffineTransform(rotationAngle: .pi / 2)
        case .upsideDown:
            return CGAffineTransform(rotationAngle: .pi)
        }
    }
}

class FullscreenManager {
    enum Event {
        case willEnter(RotationTransform)
        case didEnter(RotationTransform)
        case willExit
        case didExit
    }

    /// The orientations for applying rotate transform when device orientation changed
    var orientationsForApplyingRotateTransform: UIInterfaceOrientationMask = []

    /// `shouldHideStatusBar` always be `YES` when applying rotate transfrom if not in portrait orientation.
    var shouldHideStatusBar: Bool = false {
        didSet {
            updateStatusBarDisplay()
        }
    }

    weak var playbackView: UIView?
    weak var containerView: UIView?

    var isFullscreen: Bool {
        guard let window else { return false }

        return !window.isHidden
    }

    private let eventHandler: (Event) -> Void

    private(set) var window: FullscreenWindow?
    private weak var sourceWindow: UIWindow?
    private var currentRotation: RotationTransform = .none

    private let orientationObserver = OrientationObserver()
    private var orientationObservation: AnyCancellable?

    init(playbackView: UIView, containerView: UIView?, eventHandler: @escaping (Event) -> Void) {
        self.playbackView = playbackView
        self.containerView = containerView
        self.eventHandler = eventHandler

        orientationObservation = orientationObserver.orientationPulisher
            .sink { [weak self] in
                guard let self else { return }

                self.orientationDidChange($0)
            }
    }

    func enterFullscreen() {
        guard !isFullscreen else { return }

        let currentOrientation = orientationObserver.orientation
        let rotation: RotationTransform = if orientationsForApplyingRotateTransform.contains(currentOrientation) {
            // Keep current orientation and apply rotate transform
            RotationTransform(orientation: currentOrientation)
        } else {
            .none
        }

        _enterFullscreen(with: rotation)
    }

    func exitFullscreen() {
        guard isFullscreen else { return }

        _exitFullscreen()
    }

    private func orientationDidChange(_: UIInterfaceOrientation) {
        guard isFullscreen, UIDevice.current.orientation.isValidInterfaceOrientation else { return }

        let currentOrientation = orientationObserver.orientation
        let toRotation: RotationTransform = if orientationsForApplyingRotateTransform.contains(currentOrientation) {
            RotationTransform(orientation: currentOrientation)
        } else {
            .none
        }

        guard toRotation != currentRotation else { return }

        _enterFullscreen(with: toRotation)
    }

    private func updateStatusBarDisplay() {
        if isFullscreen, currentRotation != .none {
            window?.viewController.shouldHideStatusBar = true
        } else {
            window?.viewController.shouldHideStatusBar = shouldHideStatusBar
        }
    }

    private func _enterFullscreen(with rotation: RotationTransform) {
        guard let playbackView, let containerView else {
            Logs.error("playbackView or containerView is nil")
            return
        }

        let fromRotation = currentRotation
        let toRotation = rotation

        let window = self.window ?? FullscreenWindow()
        self.window = window

        if !isFullscreen {
            // Add playbackView to window temporarily for transition
            guard let sourceWindow = containerView.window else { return }

            self.sourceWindow = sourceWindow

            let sourceRect = containerView.convert(containerView.bounds, to: sourceWindow)

            sourceWindow.addSubview(playbackView)
            playbackView.autoresizingMask = []
            playbackView.frame = sourceRect
            playbackView.layoutIfNeeded()

            if !window.isKeyWindow {
                window.isHidden = false
                window.makeKeyAndVisible()
            }
        }

        currentRotation = toRotation
        updateStatusBarDisplay()
        eventHandler(.willEnter(toRotation))

        // Transition
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveOut) {
            playbackView.transform = toRotation.transform
            if toRotation.isLandscape, !fromRotation.isLandscape {
                playbackView.bounds = CGRect(origin: .zero, size: CGSize(width: window.bounds.height, height: window.bounds.width))
            } else {
                playbackView.bounds = window.bounds
            }
            playbackView.center = window.center
            playbackView.layoutIfNeeded()

        } completion: { _ in
            playbackView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            window.viewController.view.addSubview(playbackView)
            playbackView.frame = window.bounds
            playbackView.layoutIfNeeded()

            self.eventHandler(.didEnter(toRotation))
        }
    }

    private func _exitFullscreen() {
        guard let containerView, let playbackView else {
            sourceWindow?.makeKeyAndVisible()
            return
        }

        guard let sourceWindow = containerView.window else {
            playbackView.removeFromSuperview()
            return
        }
        let sourceRect = containerView.convert(containerView.bounds, to: sourceWindow)
        let screenBounds = UIScreen.main.bounds
        let maxSize = max(screenBounds.width, screenBounds.height)
        let minSize = min(screenBounds.width, screenBounds.height)

        playbackView.autoresizingMask = []
        playbackView.bounds = if currentRotation.isLandscape {
            .init(origin: .zero, size: .init(width: maxSize, height: minSize))
        } else {
            .init(origin: .zero, size: .init(width: minSize, height: maxSize))
        }
        playbackView.center = .init(x: minSize / 2, y: maxSize / 2)

        // Add playbackView to sourceWindow temporarily for transition
        sourceWindow.addSubview(playbackView)
        sourceWindow.makeKeyAndVisible()
        playbackView.layoutIfNeeded()
        window?.isHidden = true

        currentRotation = .none
        eventHandler(.willExit)

        // Transition
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveOut) {
            playbackView.transform = .identity
            playbackView.frame = sourceRect
            playbackView.layoutIfNeeded()
        } completion: { _ in
            playbackView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            containerView.addSubview(playbackView)
            playbackView.frame = containerView.bounds
            playbackView.layoutIfNeeded()

            self.eventHandler(.didExit)
        }
    }
}

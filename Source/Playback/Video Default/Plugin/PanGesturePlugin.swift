//
//  PanGesturePlugin.swift
//  Playback
//
//  Created by xueqooy on 2024/12/2.
//

import Combine
import XUI
import XKit
import PlaybackFoundation
import MediaPlayer
import UIKit

public class PanGesturePlugin: NSObject, PlayerPlugin {
    private(set) lazy var panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(Self.panGestureAction))
    private lazy var volumeIndicator = IntensityIndicatorView(style: .volume)
    private lazy var brightnessIndicator = IntensityIndicatorView(style: .brightness)
    private var autoHideVolumeIndicatorTimer: XKit.Timer?

    private weak var player: HybridMediaPlayer?
    private weak var controlView: PlaybackControllable?
    private var observations = [AnyCancellable]()
    
    public override init() {
        super.init()
        
        panGestureRecognizer.delegate = self
    }
    
    public func attach(to player: HybridMediaPlayer) {
        detach()
        
        let controlView = player.controlView
        self.controlView = controlView

        controlView.addGestureRecognizer(panGestureRecognizer)

        player.$playbackState.didChange
            .sink { [weak self] in
                guard let self else { return }

                let isGestureEnabled = $0 != .idle && $0 != .ready && $0 != .loading

                self.panGestureRecognizer.isEnabled = isGestureEnabled
            }
            .store(in: &observations)
        
        // Observe system volume change
        SystemVolumeController.shared.volumeChangedPublisher
            .sink { [weak self] value in
                guard let self, let playbackState = self.player?.playbackState, playbackState == .playing || playbackState == .stalled else { return }

                // Ignore volume changed notification when the user is controlling the volume
                if case .volume = self.controlTarget {
                    return
                }

                self.showVolumeIndicator(with: value, automaticallyHide: true)
            }
            .store(in: &observations)
    }
    
    public func detach() {
        observations.removeAll(keepingCapacity: true)
        controlView?.removeGestureRecognizer(panGestureRecognizer)
        volumeIndicator.removeFromSuperview()
        brightnessIndicator.removeFromSuperview()
        autoHideVolumeIndicatorTimer = nil
        player = nil
        controlView = nil
    }

    private enum ControlTarget {
        case time(startTime: TimeInterval, duration: TimeInterval)
        case brightness(startValue: Double)
        case volume(startValue: Float)
    }

    private var controlTarget: ControlTarget?
    private var startPoint: CGPoint = .zero

    @objc private func panGestureAction(_ gesture: UIPanGestureRecognizer) {
        guard let view = gesture.view else { return }

        let velocity = gesture.velocity(in: view)
        let location = gesture.location(in: view)

        switch gesture.state {
        case .began:
            startPoint = location
            if abs(velocity.x) > abs(velocity.y) {
                guard let currentTime = player?.currentTime, let duration = player?.duration, duration > 0 else { return }

                controlView?.startSeeking(with: nil)

                // Start to control playback progress
                controlTarget = .time(startTime: currentTime, duration: duration)

            } else {
                if location.x < view.bounds.midX {
                    // Start to control brightness
                    let currentBrightness = UIScreen.main.brightness
                    controlTarget = .brightness(startValue: currentBrightness)
                } else {
                    // Start to control volume
                    let currentVolume = AVAudioSession.sharedInstance().outputVolume
                    controlTarget = .volume(startValue: currentVolume)

                    // Hide system volume indicator when controlling
                    SystemVolumeController.shared.isSystemVolumeIndicatorHidden = true
                }
            }

        case .changed:
            let translation = gesture.translation(in: view)
            switch controlTarget {
            case let .time(currentTime, duration):
                // Set the scale according to the duration to achieve fine control of time
                let pendingTime = calculateTime(withCurrentTime: currentTime, duration: duration, translation: translation, velocity: velocity, boundingWidth: view.bounds.width)

                let progressValue = Float(pendingTime / duration)
                controlView?.startSeeking(with: progressValue)

            case let .brightness(startValue):
                let delta = translation.y / view.bounds.height
                let newValue = max(0, min(1, startValue - delta))
                UIScreen.main.brightness = newValue

                showBrightnessIndicator(with: Float(newValue))

            case let .volume(startValue):
                let delta = Float(translation.y / view.bounds.height)
                let newValue = max(0, min(1, startValue - delta))

                showVolumeIndicator(with: newValue)

                SystemVolumeController.shared.volume = newValue

            default:
                break
            }

        default:
            switch controlTarget {
            case .time:
                controlView?.endSeeking()

            case .volume:
                hideVolumeIndicator()

                SystemVolumeController.shared.isSystemVolumeIndicatorHidden = false

            case .brightness:
                hideBrightnessIndicator()

            default:
                break
            }

            controlTarget = nil
        }
    }

    private func calculateTime(withCurrentTime currentTime: TimeInterval, duration: TimeInterval, translation: CGPoint, velocity: CGPoint, boundingWidth: CGFloat) -> TimeInterval {
        let baseScale = 3.0
        var scale = baseScale * boundingWidth / duration
        scale = min(10, max(5, scale))

        let deltaTime = translation.x / scale

        let velocityFactor = velocity.x / 300
        let adjustedDelta = deltaTime + velocityFactor

        let expectedTime = currentTime + adjustedDelta

        return min(duration, max(0, expectedTime))
    }

    private func showVolumeIndicator(with value: Float, automaticallyHide: Bool = false) {
        if let autoHideVolumeIndicatorTimer {
            autoHideVolumeIndicatorTimer.stop()
            self.autoHideVolumeIndicatorTimer = nil
        }

        volumeIndicator.value = value

        guard let controlView else { return }

        if volumeIndicator.superview !== controlView {
            controlView.addSubview(volumeIndicator)
            volumeIndicator.snp.makeConstraints { make in
                make.center.equalTo(controlView)
            }
        }

        if volumeIndicator.alpha == 0 {
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveOut) {
                self.volumeIndicator.alpha = 1
            }
        }

        if automaticallyHide {
            autoHideVolumeIndicatorTimer = .init(interval: 1) { [weak self] in
                guard let self else { return }

                self.hideVolumeIndicator()
            }
            autoHideVolumeIndicatorTimer!.start()
        }
    }

    private func hideVolumeIndicator() {
        if let autoHideVolumeIndicatorTimer {
            autoHideVolumeIndicatorTimer.stop()
            self.autoHideVolumeIndicatorTimer = nil
        }

        guard volumeIndicator.alpha > 0 else { return }

        UIView.animate(withDuration: 0.25, delay: 0, options: .curveOut) {
            self.volumeIndicator.alpha = 0
        }
    }

    private func showBrightnessIndicator(with value: Float) {
        brightnessIndicator.value = value

        guard let controlView else { return }

        if brightnessIndicator.superview !== controlView {
            controlView.addSubview(brightnessIndicator)
            brightnessIndicator.snp.makeConstraints { make in
                make.center.equalTo(controlView)
            }
        }

        if brightnessIndicator.alpha == 0 {
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveOut) {
                self.brightnessIndicator.alpha = 1
            }
        }
    }

    private func hideBrightnessIndicator() {
        guard brightnessIndicator.alpha > 0 else { return }

        UIView.animate(withDuration: 0.25, delay: 0, options: .curveOut) {
            self.brightnessIndicator.alpha = 0
        }
    }
}

extension PanGesturePlugin: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let controlView, gestureRecognizer === panGestureRecognizer else { return false }

        for view in controlView.allEdgeViews {
            if view.isVisible() {
                let location = touch.location(in: view)
                if view.bounds.contains(location) {
                    return false
                }
            }
        }

        return true
    }

    public func gestureRecognizer(_: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Prevent the pan gesture from being recognized when the user is scrolling
        if "\(type(of: otherGestureRecognizer))" == "UIScrollViewPanGestureRecognizer" {
            return true
        }

        return false
    }
}

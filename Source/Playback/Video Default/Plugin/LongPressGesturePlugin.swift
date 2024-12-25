//
//  LongPressGesturePlugin.swift
//  Playback
//
//  Created by xueqooy on 2024/12/3.
//

import Combine
import UIKit
import XKit
import XUI

public class LongPressGesturePlugin: NSObject, PlayerPlugin {
    private(set) lazy var longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(Self.longPressGestureAction))

    private weak var player: HybridMediaPlayer?
    private weak var controlView: PlaybackControllable?

    private lazy var indicator = FastForwardIndicatorView()

    private var observation: AnyCancellable?

    override public init() {
        super.init()

        longPressGestureRecognizer.minimumPressDuration = 0.75
        longPressGestureRecognizer.delegate = self
    }

    public func attach(to player: HybridMediaPlayer) {
        detach()

        self.player = player

        let controlView = player.controlView
        self.controlView = controlView
        controlView.addGestureRecognizer(longPressGestureRecognizer)

        observation = player.$playbackState.didChange
            .sink { [weak self] in
                guard let self else { return }

                let isGestureEnabled = $0 != .idle && $0 != .loading && $0 != .ready

                self.longPressGestureRecognizer.isEnabled = isGestureEnabled
            }
    }

    public func detach() {
        indicator.removeFromSuperview()
        controlView?.removeGestureRecognizer(longPressGestureRecognizer)
        observation = nil
        player = nil
    }

    @objc private func longPressGestureAction(_ gesture: UILongPressGestureRecognizer) {
        guard let player else { return }

        switch gesture.state {
        case .began:
            showFastForwardIndicator(rate: 3)
            player.setRate(3)

        case .ended, .cancelled, .failed:
            hideFastForwardIndicator()
            player.setRate(1)

        default:
            break
        }
    }

    private func showFastForwardIndicator(rate: Float) {
        indicator.rate = rate

        guard let controlView else { return }

        if indicator.superview !== controlView {
            controlView.addSubview(indicator)
            indicator.snp.makeConstraints { make in
                if let topView = controlView.topView {
                    make.top.equalTo(topView.snp.bottom)
                } else {
                    make.centerY.equalToSuperview()
                }
                make.centerX.equalToSuperview()
            }
        }

        if indicator.alpha == 0 {
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveOut) {
                self.indicator.alpha = 1
            }
        }
    }

    private func hideFastForwardIndicator() {
        guard indicator.alpha > 0 else { return }

        UIView.animate(withDuration: 0.25, delay: 0, options: .curveOut) {
            self.indicator.alpha = 0
        }
    }
}

extension LongPressGesturePlugin: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let controlView, let player, gestureRecognizer === longPressGestureRecognizer, player.playbackState == .playing else { return false }

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
}

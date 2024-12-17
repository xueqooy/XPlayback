//
//  Player+AutoPauseOnScrollView.swift
//  Pods
//
//  Created by xueqooy on 2024/12/12.
//

import Combine
import XKit
import Foundation

private let scrollingObservationAssociation = Association<AnyCancellable>()

/// Pause playback when the container moves off the screen.
public extension Player {
    func maybeAddScrollingObserverForAutoPause() {
        guard let scrollView = containerView?.findScrollView() else { return }

        scrollingObservationAssociation[self] = scrollView.publisher(for: \.contentOffset)
            .throttle(for: .milliseconds(200), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self, weak scrollView] _ in
                guard let self, let scrollView else { return }

                self.scrollViewDidScroll(scrollView)
            }
    }

    func removeScrollingObserverForAutoPause() {
        scrollingObservationAssociation[self] = nil
    }

    private func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let containerView, containerView.isDescendant(of: scrollView) else {
            removeScrollingObserverForAutoPause()
            return
        }

        guard !checkContainerVisibility(in: scrollView), isPlaying else {
            return
        }

        pause()
    }

    private func checkContainerVisibility(in scrollView: UIScrollView) -> Bool {
        guard let containerView, containerView.isVisible() else {
            return false
        }

        let rect = containerView.convert(containerView.bounds, to: scrollView.superview)
        return scrollView.frame.intersects(rect)
    }
}

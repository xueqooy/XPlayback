//
//  SeekingPreviewPlugin.swift
//  Playback
//
//  Created by xueqooy on 2024/12/2.
//

import Combine
import XUI
import XKit
import UIKit

public class SeekingPreviewPlugin: PlayerPlugin {
    private var previewThumbnailTask: Task<Void, Never>?
    // Prevent from starting preview thumbnail task too frequently
    private let throttleToStartPreviewThumbnailTaskSubject = PassthroughSubject<TimeInterval, Never>()
    private var throttleCancellable: AnyCancellable?

    private lazy var view = SeekingPreviewView()
        .settingHidden(true)

    private weak var player: HybridMediaPlayer?
    private weak var controlView: PlaybackControllable?
    private var observations = [AnyCancellable]()

    public init() {
        throttleCancellable = throttleToStartPreviewThumbnailTaskSubject
            .throttle(for: .milliseconds(200), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] in
                self?.startPreviewThumbnailTask(with: $0)
            }
    }

    public func attach(to player: HybridMediaPlayer) {
        self.detach()
        
        let controlView = player.controlView
        
        self.player = player
        self.controlView = controlView
        
        controlView.pendingTimeToSeekUpdatedPublisher
            .sink { [weak self] in
                // Show preview when seeking
                self?.showPreviewView(with: $0)
            }
            .store(in: &observations)

        controlView.timeToSeekPublisher
            .sink { [weak self] _ in
                // hide preview after seeking ended
                self?.hidePreviewView()
            }
            .store(in: &observations)
    }
    
    public func detach() {
        observations.removeAll(keepingCapacity: true)
        previewThumbnailTask?.cancel()
        previewThumbnailTask = nil
        player = nil
        controlView = nil
    }
    
    
    private func showPreviewView(with pendingTimeToSeek: TimeInterval) {
        guard let controlView, let player else { return }

        // Add preview to contaienr
        if view.superview !== controlView {
            controlView.addSubview(view)
            view.snp.makeConstraints { make in
                make.centerX.equalToSuperview()
                if let bottomView = controlView.bottomView {
                    make.bottom.equalTo(bottomView.snp.top).offset(-CGFloat.XUI.spacing2)
                } else {
                    make.centerY.equalToSuperview()
                }
            }
        }

        view.duration = player.duration

        if view.isHidden {
            // Start preview thumbnail task immediately for the first time
            startPreviewThumbnailTask(with: pendingTimeToSeek)
        }

        view.isHidden = false
        view.timeToSeek = pendingTimeToSeek

        throttleToStartPreviewThumbnailTaskSubject.send(pendingTimeToSeek)
    }

    private func hidePreviewView() {
        previewThumbnailTask?.cancel()
        view.isHidden = true
        view.image = nil
    }

    private func startPreviewThumbnailTask(with pendingTimeToSeek: TimeInterval) {
        previewThumbnailTask?.cancel()
        previewThumbnailTask = Task { @MainActor [weak self] in
            guard let self, let player = self.player else { return }

            let image = await player.thumbnail(at: pendingTimeToSeek, size: self.view.bounds.size)

            guard !self.view.isHidden else { return }

            do {
                try Task.checkCancellation()

                self.view.image = image
            } catch {}
        }
    }
}

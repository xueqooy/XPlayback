//
//  DefaultAudioControlView.swift
//  Pods
//
//  Created by xueqooy on 2024/12/16.
//

import UIKit
import XUI
import Combine

public class DefaultAudioControlView: UIView, PlaybackControllable {
    
    private lazy var playOrPauseButton = createButton(image: ButtonImage.play)
    private lazy var progressView = PlaybackProgressView(tintColor: .black)
    private lazy var speakerButton = createButton(image: ButtonImage.unmute)
    
    private weak var player: HybridMediaPlayer?
    private var playerObservations = [AnyCancellable]()

    public init() {
        super.init(frame: .zero)
        
        let backgroundView = BackgroundView(configuration: .init(fillColor: Colors.background1, cornerStyle: .capsule))
        addSubview(backgroundView) {
            $0.edges.equalToSuperview()
        }
        
        let stackView = HStackView(alignment: .center, spacing: .XUI.spacing3, layoutMargins: .init(top: 0, left: .XUI.spacing3, bottom: 0, right: .XUI.spacing3)) {
            playOrPauseButton
            progressView
            speakerButton
        }
        addSubview(stackView) {
            $0.left.right.centerY.equalToSuperview()
        }
        
        playOrPauseButton.touchUpInsideAction = { [weak self] _ in
            guard let self, let player = self.player else { return }

            if player.playbackState == .playing || player.playbackState == .stalled {
                player.pause()
            } else {
                player.play()
            }
        }

        progressView.eventHandler = { [weak self] event in
            guard let self, let player = self.player else { return }

            if case let .requestToSeek(timeToSeek) = event {
                player.seek(to: timeToSeek)
            }
        }
        
        speakerButton.touchUpInsideAction = { [weak self] _ in
            guard let self, let player = self.player else { return }

            player.setMuted(!player.isMuted)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func attach(to player: HybridMediaPlayer) {
        playerObservations.removeAll(keepingCapacity: true)
                
        self.player = player
        
        player.$duration.didChange
            .sink { [weak self] in
                self?.progressView.timeInfo.duration = $0
            }
            .store(in: &playerObservations)
        
        player.$currentTime.didChange
            .sink { [weak self] in
                self?.progressView.timeInfo.currentTime = $0
            }
            .store(in: &playerObservations)
        
        player.$bufferedPosition.didChange
            .sink { [weak self] in
                self?.progressView.timeInfo.bufferedPosition = $0
            }
            .store(in: &playerObservations)
        
        player.$isMuted.didChange
            .sink { [weak self] in
                self?.speakerButton.configuration.image = $0 ? ButtonImage.mute : ButtonImage.unmute
            }
            .store(in: &playerObservations)
        
        player.$playbackState.didChange
            .sink { [weak self] in
                guard let self else { return }
                
                self.playOrPauseButton.configuration.image = $0 == .playing || $0 == .stalled ? ButtonImage.pause : ButtonImage.play
                self.progressView.state = switch $0 {
    //            case .idle, .loading, .stalled:
    //                PlaybackProgressView.State.loading

                case .failed:
                    PlaybackProgressView.State.failed

                default:
                    PlaybackProgressView.State.normal
                }
            }
            .store(in: &playerObservations)
    }
    
    public func startSeeking(with value: Float?) {
        if let value {
            progressView.sendActionsToSlider(for: .valueChanged, with: value)
        } else {
            progressView.sendActionsToSlider(for: .touchDown)
        }
    }
    
    public func endSeeking() {
        progressView.sendActionsToSlider(for: .touchCancel)
    }
    
    
    private func createButton(image: UIImage) -> Button {
        let button = Button(image: image, foregroundColor: .black)
        button.hitTestSlop = .init(top: -10, left: -6, bottom: -10, right: -6) // Horizontal slop flows spacing of stack (spacing / 2)
        button.imageTransition = [.fade, .scale]
        button.settingSizeConstraint(.square(15))
        return button
    }

    public override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 33)
    }
}

// MARK: - Button Image

private extension DefaultAudioControlView {
    enum ButtonImage {
        static let play = Icons.play

        static let pause = Icons.pause

        static let mute = Icons.speakerOff

        static let unmute = Icons.speakerOn
    }
}

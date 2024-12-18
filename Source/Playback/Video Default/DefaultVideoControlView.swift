//
//  DefaultVideoControlView.swift
//  Playback
//
//  Created by xueqooy on 2024/11/28.
//

import Combine
import XUI
import XKit
import PlaybackFoundation
import UIKit

public class DefaultVideoControlView: UIView, PlaybackControllable {

    public var pendingTimeToSeekUpdatedPublisher: AnyPublisher<TimeInterval, Never> {
        pendingTimeToSeekUpdatedSubject.eraseToAnyPublisher()
    }

    public var timeToSeekPublisher: AnyPublisher<TimeInterval, Never> {
        timeToSeekSubject.eraseToAnyPublisher()
    }
    
    public var topView: UIView? { topBar }
    public var bottomView: UIView? { bottomBar }

    private lazy var topBar: UIView = ControlBar(position: .top)
    private lazy var bottomBar: UIView = ControlBar(position: .bottom)
    private lazy var titleLabel = UILabel(textColor: .white, font: Fonts.body2Bold)
    private lazy var fullscreenButton = createButton(image: ButtonImage.expand)
    private lazy var playOrPauseButton = createButton(image: ButtonImage.play)
    private lazy var progressView = PlaybackProgressView(tintColor: .white)
    private lazy var speakerButton = createButton(image: ButtonImage.unmute)
    private lazy var activityIndicator = ActivityIndicatorView(color: .white)

    private let pendingTimeToSeekUpdatedSubject = PassthroughSubject<TimeInterval, Never>()
    private let timeToSeekSubject = PassthroughSubject<TimeInterval, Never>()

    private weak var player: HybridMediaPlayer?
    private var playerObservations = [AnyCancellable]()
    
    override init(frame: CGRect) {
        super.init(frame: frame)

        setupTopBar()
        setupBottomBar()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func attach(to player: HybridMediaPlayer) {
        playerObservations.removeAll(keepingCapacity: true)
        
        self.player = player
        
        player.$style.didChange
            .sink { [weak self] in
                self?.updateStyle($0)
            }
            .store(in: &playerObservations)
        
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
               case .idle, .loading, .stalled:
                   PlaybackProgressView.State.loading

                case .failed:
                    PlaybackProgressView.State.failed

                default:
                    PlaybackProgressView.State.normal
                }
                   
                if self.progressView.state == .loading {
                    self.showActivityIndicator()
                } else {
                    self.hideActivityIndicator()
                }
            }
            .store(in: &playerObservations)
        
        player.$hint.didChange
            .sink { [weak self] hint in
                guard let self else { return }
                
                self.titleLabel.text = hint?.title
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
    
    private func setupTopBar() {
        (topBar as! ControlBar).stackView.populate {
            titleLabel
            
            SpacerView.flexible()

            fullscreenButton
        }

        addSubview(topBar) {
            $0.left.right.top.equalToSuperview()
        }

        fullscreenButton.touchUpInsideAction = { [weak self] _ in
            guard let self, let player = self.player else { return }

            if player.style.isFullscreen {
                player.exitFullscreen()
            } else {
                player.enterFullscreen()
            }
        }
    }

    private func setupBottomBar() {
        (bottomBar as! ControlBar).stackView.populate {
            playOrPauseButton

            progressView

            speakerButton
        }

        addSubview(bottomBar) {
            $0.left.right.bottom.equalToSuperview()
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

            switch event {
            case let .pendingTimeToSeekUpdated(pendingTimeToSeek):
                self.pendingTimeToSeekUpdatedSubject.send(pendingTimeToSeek)

            case let .requestToSeek(timeToSeek):
                self.timeToSeekSubject.send(timeToSeek)

                player.seek(to: timeToSeek)
            }
        }

        speakerButton.touchUpInsideAction = { [weak self] _ in
            guard let self, let player = self.player else { return }

            player.setMuted(!player.isMuted)
        }
    }

    private func updateStyle(_ style: PlaybackStyle) {
        let topBar = topBar as! ControlBar
        let bottomBar = bottomBar as! ControlBar

        switch style {
        case .inline:
            fullscreenButton.configuration.image = ButtonImage.expand

            topBar.edgeMode = .respectSafeArea
            bottomBar.edgeMode = .respectSafeArea

        case let .fullscreen(rotationTransform):
            fullscreenButton.configuration.image = ButtonImage.collapse

            // When the view applies transform, the layout based on safeArea may be strange, so manually adjust the edge inset with layoutMargins
            switch rotationTransform {
            case .none:
                topBar.edgeMode = .respectSafeArea
                bottomBar.edgeMode = .respectSafeArea

            case .left, .right:
                topBar.layoutMargins = UIEdgeInsets(top: .XUI.spacing5, left: .XUI.spacing10, bottom: 0, right: .XUI.spacing10)
                bottomBar.layoutMargins = UIEdgeInsets(top: 0, left: .XUI.spacing10, bottom: .XUI.spacing5, right: .XUI.spacing10)

                topBar.edgeMode = .respectLayoutMargins
                bottomBar.edgeMode = .respectLayoutMargins

            case .upsideDown:
                topBar.layoutMargins = UIEdgeInsets(top: .XUI.spacing10, left: 0, bottom: 0, right: 0)
                bottomBar.layoutMargins = UIEdgeInsets(top: 0, left: 0, bottom: .XUI.spacing10, right: 0)

                topBar.edgeMode = .respectLayoutMargins
                bottomBar.edgeMode = .respectLayoutMargins
            }
        }
    }

    private func showActivityIndicator() {
        if activityIndicator.superview !== self {
            addSubview(activityIndicator) {
                $0.center.equalToSuperview()
            }
        }
        
        activityIndicator.isHidden = false
        activityIndicator.startAnimating()
    }
    
    private func hideActivityIndicator() {
        activityIndicator.isHidden = true
        activityIndicator.stopAnimating()
    }
    
    private func createButton(image: UIImage) -> Button {
        let button = Button(image: image, foregroundColor: .white)
        button.hitTestSlop = .init(top: -10, left: -6, bottom: -10, right: -6) // Horizontal slop flows spacing of stack (spacing / 2)
        button.imageTransition = [.fade, .scale]
        button.settingSizeConstraint(.square(20))
        return button
    }
}

// MARK: - Button Image

private extension DefaultVideoControlView {
    enum ButtonImage {
        static let play = Icons.play

        static let pause = Icons.pause

        static let mute = Icons.speakerOff

        static let unmute = Icons.speakerOn

        static let expand = Icons.expand

        static let collapse = Icons.collapse
    }
}

// MARK: - PlaybackControlBar
private class ControlBar: UIView {
    enum Position {
        case top, bottom
    }

    enum EdgeMode {
        case respectSafeArea
        case respectLayoutMargins
    }

    var edgeMode: EdgeMode = .respectSafeArea {
        didSet {
            guard oldValue != edgeMode else { return }

            updateLayout()
        }
    }

    let stackView = HStackView(alignment: .center, spacing: .XUI.spacing3, layoutMargins: .init(top: 0, left: .XUI.spacing3, bottom: 0, right: .XUI.spacing3))
        .settingHeightConstraint(44)

    let position: Position

    init(position: Position) {
        self.position = position

        super.init(frame: .zero)

        let colors = switch position {
        case .top:
            [UIColor.black.withAlphaComponent(0.7), UIColor.black.withAlphaComponent(0)]
        case .bottom:
            [UIColor.black.withAlphaComponent(0), UIColor.black.withAlphaComponent(0.7)]
        }
        let gradient = BackgroundConfiguration.Gradient(colors: colors, startPoint: .init(x: 0.5, y: 0), endPoint: CGPoint(x: 0.5, y: 1))
        let backgroundView = BackgroundView(configuration: .init(gradient: gradient))

        addSubview(backgroundView) { make in
            make.edges.equalToSuperview()
        }

        addSubview(stackView)
        updateLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateLayout() {
        switch edgeMode {
        case .respectSafeArea:
            stackView.snp.remakeConstraints { make in
                make.left.right.equalTo(self.safeAreaLayoutGuide)

                switch position {
                case .top:
                    make.top.equalTo(self.safeAreaLayoutGuide)
                    make.bottom.equalToSuperview()
                case .bottom:
                    make.top.equalToSuperview()
                    make.bottom.equalTo(self.safeAreaLayoutGuide)
                }
            }
        case .respectLayoutMargins:
            insetsLayoutMarginsFromSafeArea = false
            stackView.snp.remakeConstraints { make in
                make.left.right.equalTo(self.layoutMarginsGuide)

                switch position {
                case .top:
                    make.top.equalTo(self.layoutMarginsGuide)
                    make.bottom.equalToSuperview()
                case .bottom:
                    make.top.equalToSuperview()
                    make.bottom.equalTo(self.layoutMarginsGuide)
                }
            }
        }
    }

    override func point(inside point: CGPoint, with _: UIEvent?) -> Bool {
        bounds.inset(by: .init(top: 0, left: -.XUI.spacing3, bottom: 0, right: -.XUI.spacing3)).contains(point)
    }
}

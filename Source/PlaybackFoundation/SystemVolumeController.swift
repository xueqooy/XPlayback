//
//  SystemVolumeController.swift
//  Playback
//
//  Created by xueqooy on 2024/12/2.
//

import Combine
import XKit
import MediaPlayer
import UIKit

public class SystemVolumeController {
    public static let shared = SystemVolumeController()

    public var volumeChangedPublisher: AnyPublisher<Float, Never> {
        volumeChangedSubject
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    private var recordedVolume: Float?

    public var volume: Float {
        get {
            AVAudioSession.sharedInstance().outputVolume
        }
        set {
            volumeSlider?.value = newValue
        }
    }

    public var isSystemVolumeIndicatorHidden: Bool {
        get { volumeView?.isHidden == false }
        set {
            // System volume indicator will display when custom volume view is hidden
            volumeView?.isHidden = !newValue
        }
    }

    private var volumeView: MPVolumeView?
    private var volumeSlider: UISlider?

    private var volumeChangedSubject = PassthroughSubject<Float, Never>()

    private var appStateObservations = [AnyCancellable]()
    private var audioSessionObservation: AnyCancellable?

    public func start() {
        guard volumeView == nil else { return }

        let volumeView = MPVolumeView(frame: .init(x: -100, y: -100, width: 100, height: 100))
        self.volumeView = volumeView
        volumeView.isHidden = true

        // Add a custom volume view to control the display of the system volume indicator
        UIApplication.shared.delegate?.window??.addSubview(volumeView)
        
        var volumeSlider: UISlider?
        for view in volumeView.subviews {
            if let slider = view as? UISlider {
                volumeSlider = slider
                break
            }
        }

        if let volumeSlider {
            self.volumeSlider = volumeSlider
            volumeSlider.value = volume
        } else {
            Logs.error("Failed to find volume slider", tag: "Playback")
        }

        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                guard let self else { return }

                self.startObservingAudioSession()
            }
            .store(in: &appStateObservations)

        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                guard let self else { return }

                self.stopObservingAudioSession()
            }
            .store(in: &appStateObservations)

        if UIApplication.shared.applicationState == .active {
            startObservingAudioSession()
        }
    }

    public func stop() {
        guard let volumeView else { return }

        appStateObservations.removeAll()
        stopObservingAudioSession()

        volumeView.removeFromSuperview()
        self.volumeView = nil
        volumeSlider = nil
    }

    public func recordVolume(_ volume: Float) {
        recordedVolume = volume
    }

    @discardableResult
    public func restoreRecordedVolume() -> Bool {
        guard let recordedVolume = recordedVolume else { return false }

        volume = recordedVolume
        return true
    }

    private func startObservingAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(true)

            audioSessionObservation = AVAudioSession.sharedInstance().publisher(for: \.outputVolume)
                .sink { [weak self] volume in
                    guard let self else { return }

                    self.volumeChangedSubject.send(volume)
                }
        } catch {
            Logs.error("Failed to set audio session active: \(error)", tag: "Playback")
        }
    }

    private func stopObservingAudioSession() {
        audioSessionObservation?.cancel()
        audioSessionObservation = nil
    }
}

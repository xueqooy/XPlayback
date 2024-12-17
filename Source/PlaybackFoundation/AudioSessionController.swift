//
//  AudioSessionController.swift
//  Playback
//
//  Created by xueqooy on 2024/12/9.
//

import AVFoundation
import Combine
import Foundation

public enum InterruptionType: Equatable {
    case began
    case ended(shouldResume: Bool)
}

/**
 Simple manager for the `AVAudioSession`. If you need more advanced options, just use the `AVAudioSession` directly.
 - warning: Do not combine usage of this and `AVAudioSession` directly, chose one.
 */
public class AudioSessionController {
    public static let shared = AudioSessionController()

    public var interruptionPublisher: some Publisher<InterruptionType, Never> {
        interruptionSubject
    }

    /**
     True if another app is currently playing audio.
     */
    public var isOtherAudioPlaying: Bool {
        audioSession.isOtherAudioPlaying
    }

    /**
     True if the audiosession is active.

     - warning: This will only be correct if the audiosession is activated through this class!
     */
    public var audioSessionIsActive: Bool = false

    public var category: AVAudioSession.Category {
        audioSession.category
    }

    /**
     Wheter notifications for interruptions are being observed or not.
     This is enabled by default.
     Set this to false to disable the behaviour.
     */
    public var isObservingForInterruptions: Bool {
        get { observation != nil }
        set {
            if newValue == isObservingForInterruptions {
                return
            }

            if newValue {
                registerForInterruptionNotification()
            } else {
                unregisterForInterruptionNotification()
            }
        }
    }

    private let audioSession = AVAudioSession.sharedInstance()
    private let notificationCenter = NotificationCenter.default
    private var observation: AnyCancellable?
    private let interruptionSubject = PassthroughSubject<InterruptionType, Never>()

    init() {
        registerForInterruptionNotification()
    }

    public func activateSession() throws {
        do {
            try audioSession.setActive(true, options: [])
            audioSessionIsActive = true
        } catch { throw error }
    }

    public func deactivateSession() throws {
        do {
            try audioSession.setActive(false, options: [])
            audioSessionIsActive = false
        } catch { throw error }
    }

    public func set(category: AVAudioSession.Category) throws {
        try audioSession.setCategory(category, mode: audioSession.mode, options: audioSession.categoryOptions)
    }

    // MARK: - Interruptions

    private func registerForInterruptionNotification() {
        observation = notificationCenter.publisher(for: AVAudioSession.interruptionNotification)
            .sink { [weak self] in
                self?.handleInterruption(notification: $0)
            }
    }

    private func unregisterForInterruptionNotification() {
        observation?.cancel()
        observation = nil
    }

    @objc func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else {
            return
        }

        switch type {
        case .began:
            interruptionSubject.send(.began)
        case .ended:
            guard let typeValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else {
                interruptionSubject.send(.ended(shouldResume: false))
                return
            }

            let options = AVAudioSession.InterruptionOptions(rawValue: typeValue)
            interruptionSubject.send(.ended(shouldResume: options.contains(.shouldResume)))
        @unknown default: return
        }
    }
}

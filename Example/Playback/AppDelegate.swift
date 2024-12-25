//
//  AppDelegate.swift
//  Playback-Demo
//
//  Created by xueqooy on 2022/12/6.
//

import Combine
import Playback
import UIKit
import XKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    private var subscriptions = Set<AnyCancellable>()

    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.

        let rootViewController = UIStoryboard(name: "Main", bundle: .main).instantiateInitialViewController()

        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = rootViewController
        window.makeKeyAndVisible()

        self.window = window

        Logs.add(ConsoleLogger.shared)

//        if UIDevice.current.userInterfaceIdiom == .phone {
//            PlaybackService.shared.orientationsForApplyingRotateTransform = [.landscapeLeft, .landscapeRight, .portraitUpsideDown]
//        }

        return true
    }

    // MARK: UISceneSession Lifecycle

//    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
//        if UIDevice.current.userInterfaceIdiom == .pad {
//            return .all
//        } else {
//            return .portrait
//        }
//    }
}

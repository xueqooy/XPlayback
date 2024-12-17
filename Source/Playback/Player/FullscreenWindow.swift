//
//  FullscreenWindow.swift
//  Playback
//
//  Created by xueqooy on 2024/12/3.
//

import XUI
import UIKit

class FullscreenWindow: UIWindow {
    let viewController = FullscreenViewController()

    init() {
        if let windowScene = UIApplication.shared.activeScene {
            let keywindow = windowScene.windows.first { $0.isKeyWindow }

            super.init(frame: keywindow?.bounds ?? UIScreen.main.bounds)
            self.windowScene = windowScene

        } else {
            super.init(frame: UIApplication.shared.keyWindows.first?.bounds ?? UIScreen.main.bounds)
        }

        viewController.loadViewIfNeeded()

        rootViewController = viewController
        windowLevel = .statusBar - 1
        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

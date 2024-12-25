//
//  DefaultQualityMenuProvider.swift
//  Playback
//
//  Created by xueqooy on 2024/12/24.
//

import Combine
import XUI

public class DefaultQualityMenuProvider: QualityMenuProviding {
    public var menuVisiblityPublisher: AnyPublisher<Bool, Never> {
        popover.$isShowing.didChange
    }

    public var isMenuVisible: Bool {
        popover.isShowing
    }

    private lazy var popover: Popover = {
        var configuration = Popover.Configuration()
        configuration.background.fillColor = Colors.background1
        configuration.preferredDirection = .down
        configuration.delayHidingOnAnchor = true
        configuration.dismissMode = .tapOnOutsidePopover
        configuration.arrowSize = .zero
        configuration.contentInsets = .init(uniformValue: .XUI.spacing2)
        configuration.offset = .init(x: 0, y: .XUI.spacing1)
        return Popover(configuration: configuration)
    }()

    public required init() {}

    public func showMenu(from view: UIView, with items: [MultiQualityAsset.Item], currentIndex: Int, selectionHandler: @escaping (Int) -> Void) {
        let buttons = items
            .enumerated()
            .map { index, item in
                let button = createMenuItemButton(for: item, isSelected: index == currentIndex)
                button.touchUpInsideAction = { [weak self] _ in
                    guard let self else { return }

                    if currentIndex != index {
                        selectionHandler(index)
                    }
                    self.popover.hide()
                }
                return button
            }

        let stackView = VStackView(arrangedSubviews: buttons)
        popover.show(stackView, from: view)
    }

    public func hideMenu() {
        popover.hide()
    }

    private func createMenuItemButton(for item: MultiQualityAsset.Item, isSelected: Bool) -> Button {
        let backgoundConfig = BackgroundConfiguration(fillColor: isSelected ? Colors.line1 : .clear, cornerStyle: .fixed(.XUI.smallCornerRadius))
        return Button(configuration: .init(title: item.label, titleFont: Fonts.caption, titleColor: Colors.bodyText1, contentInsets: .nondirectional(top: .XUI.spacing2, left: .XUI.spacing2, bottom: .XUI.spacing2, right: .XUI.spacing2), background: backgoundConfig))
    }
}

//
//  FastForwardIndicatorView.swift
//  Playback
//
//  Created by xueqooy on 2024/12/3.
//

import XUI
import UIKit

class FastForwardIndicatorView: UIView {
    var rate: Float = 0 {
        didSet {
            guard oldValue != rate else { return }

            updateText()
        }
    }

    private let imageView: UIImageView = {
        let imageView = UIImageView(contentMode: .scaleAspectFit, clipsToBounds: true, tintColor: .white)
        imageView.image = UIImage(systemName: "forward")
        return imageView
    }()

    private let textLabel = UILabel(textColor: .white, font: Fonts.body4Bold)

    override init(frame _: CGRect) {
        super.init(frame: .zero)

        backgroundColor = .init(white: 0, alpha: 0.5)
        layer.cornerRadius = .XUI.smallCornerRadius

        let stackView = HStackView(alignment: .center, spacing: .XUI.spacing2) {
            imageView

            textLabel
        }

        addSubview(stackView) {
            $0.top.bottom.equalToSuperview().inset(CGFloat.XUI.spacing2)
            $0.left.right.equalToSuperview().inset(CGFloat.XUI.spacing3)
        }

        updateText()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateText() {
        if rate <= 0 {
            textLabel.isHidden = true
        } else {
            textLabel.isHidden = false
            textLabel.text = String(format: "%.1fx", rate)
        }
    }
}

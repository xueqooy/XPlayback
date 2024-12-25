//
//  IntensityIndicatorView.swift
//  Playback
//
//  Created by xueqooy on 2024/12/2.
//

import UIKit
import XUI

class IntensityIndicatorView: UIView {
    private class Slider: UISlider {
        override init(frame: CGRect) {
            super.init(frame: frame)

            transform = CGAffineTransform(scaleX: 1, y: 0.5)
            maximumTrackTintColor = Colors.line1.withAlphaComponent(0.3)
            minimumTrackTintColor = Colors.mediumTeal
            setThumbImage(UIImage(), for: .normal)
            layer.cornerRadius = 1.5
            layer.masksToBounds = true
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func trackRect(forBounds bounds: CGRect) -> CGRect {
            var trackRect = super.trackRect(forBounds: bounds)
            trackRect.size.height = 3
            trackRect.origin.y = (bounds.height - trackRect.height) / 2

            return trackRect
        }
    }

    enum Style {
        case volume
        case brightness

        var minImage: UIImage {
            switch self {
            case .volume:
                Icons.speakerOff

            case .brightness:
                UIImage(systemName: "sun.min")!
            }
        }

        var maxImage: UIImage {
            switch self {
            case .volume:
                Icons.speakerOn

            case .brightness:
                UIImage(systemName: "sun.max")!
            }
        }
    }

    private let imageView = ImageView(tintColor: .white).then {
        $0.transition = [.fade, .scale]
    }

    private let slider = Slider()

    var value: Float {
        get { slider.value }
        set {
            let isMinBefore = value == 0

            slider.value = newValue

            let isMinAfter = newValue == 0

            if isMinBefore != isMinAfter {
                updateImage()
            }
        }
    }

    let style: Style

    init(style: Style) {
        self.style = style

        super.init(frame: .zero)

        backgroundColor = .init(white: 0, alpha: 0.5)
        layer.cornerRadius = .XUI.smallCornerRadius

        let stackView = HStackView(alignment: .center, spacing: .XUI.spacing2) {
            imageView

            slider
                .settingWidthConstraint(90)
        }.settingHeightConstraint(20)

        addSubview(stackView) {
            $0.top.bottom.equalToSuperview().inset(CGFloat.XUI.spacing2)
            $0.left.right.equalToSuperview().inset(CGFloat.XUI.spacing3)
        }

        updateImage()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateImage() {
        imageView.image = value == 0 ? style.minImage : style.maxImage
    }
}

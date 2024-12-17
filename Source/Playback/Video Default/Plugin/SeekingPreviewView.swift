//
//  SeekingPreviewView.swift
//  Playback
//
//  Created by xueqooy on 2024/12/2.
//

import XUI
import UIKit

class SeekingPreviewView: UIView {
    var image: UIImage? {
        get { imageView.image }
        set {
            imageView.image = newValue
            imageView.isHidden = newValue == nil
        }
    }

    var duration: TimeInterval = 0 {
        didSet {
            updateText()
        }
    }

    var timeToSeek: TimeInterval = 0 {
        didSet {
            updateText()
        }
    }

    private lazy var imageView: UIImageView = {
        let imageView = UIImageView(contentMode: .scaleAspectFill, clipsToBounds: true)
        imageView.layer.cornerRadius = .XUI.cornerRadius
        imageView.layer.borderWidth = 1
        imageView.layer.borderColor = UIColor.white.cgColor
        imageView.isHidden = true
        imageView.settingSizeConstraint(Device.current.isPad ? CGSize(width: 180, height: 120) : CGSize(width: 120, height: 80))
        return imageView
    }()

    private lazy var textLabel = UILabel(textColor: .white, font: Fonts.body3Bold, textAlignment: .center)

    override init(frame: CGRect) {
        super.init(frame: frame)

        let stackView = VStackView(spacing: .XUI.spacing1) {
            imageView
            textLabel
        }

        addSubview(stackView) { make in
            make.edges.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateText() {
        textLabel.richText = timeToSeek.mediaTimeString + RTText(" / \(duration.mediaTimeString)", .foreground(.init(white: 1, alpha: 0.6)))
    }
}

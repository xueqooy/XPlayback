//
//  DefaultVideoPresentationView.swift
//  Playback
//
//  Created by xueqooy on 2024/11/27.
//

import XUI
import UIKit
import PlaybackFoundation

public class DefaultVideoPresentationView: UIView, VideoPresentable {
    class CoverImageView: UIImageView {}

    public var presentationSize: CGSize = .zero {
        didSet {
            guard presentationSize != oldValue else { return }

            setNeedsLayout()
            layoutIfNeeded()
        }
    }

    public var coverImage: UIImage? {
        get { coverImageView.image }
        set { coverImageView.image = newValue }
    }

    public var isCoverHidden: Bool {
        get { coverImageView.isHidden }
        set { coverImageView.isHidden = newValue }
    }

    public var contentView: UIView? {
        didSet {
            if let oldValue, contentView !== oldValue {
                oldValue.removeFromSuperview()
            }

            if let contentView {
                addSubview(contentView)
            }

            setNeedsLayout()
            layoutIfNeeded()
        }
    }

    private lazy var coverImageView = CoverImageView(contentMode: .scaleAspectFill, clipsToBounds: true)
        .settingHidden(true)

    public override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .black

        addSubview(coverImageView)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func loadCoverImage(from url: URL) {
        coverImageView.setImage(with: url)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        guard let contentView, bounds.height > 0, presentationSize.height > 0 else { return }

        let boundingRatio = bounds.width / bounds.height
        let presentationRatio = presentationSize.width / presentationSize.height

        if boundingRatio > presentationRatio {
            let width = bounds.height * presentationRatio
            let x = (bounds.width - width) / 2

            contentView.frame = CGRect(x: x, y: 0, width: width, height: bounds.height)
        } else {
            let height = bounds.width / presentationRatio
            let y = (bounds.height - height) / 2

            contentView.frame = CGRect(x: 0, y: y, width: bounds.width, height: height)
        }

        coverImageView.frame = contentView.frame
    }

    public override func didAddSubview(_ subview: UIView) {
        if subview === contentView {
            sendSubviewToBack(subview)
        }
    }
}

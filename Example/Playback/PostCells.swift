//
//  PostCells.swift
//  Playback_Example
//
//  Created by xueqooy on 2022/12/22.
//  Copyright © 2022 CocoaPods. All rights reserved.
//

import XKit
import Playback
import UIKit

class PostBaseCell: UITableViewCell {
    
    private(set) var currentPost: Post?
    
    let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.layoutMargins = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.axis = .vertical
        stackView.spacing = 20
        return stackView
    }()

    let posterLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.label
        label.font = UIFont.preferredFont(forTextStyle: .title3)
        return label
    }()

    let contentContainerView: UIView = {
        let view = UIView()
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        setupUI()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupUI() {
        contentView.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        stackView.addArrangedSubview(posterLabel)
        stackView.addArrangedSubview(contentContainerView)
    }

    func render(_ post: Post) {
        self.currentPost = post
        posterLabel.text = post.poster
    }
}

class TextPostCell: PostBaseCell {
    let contentLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textColor = UIColor.secondaryLabel
        label.font = UIFont.preferredFont(forTextStyle: .body)
        return label
    }()

    override func setupUI() {
        super.setupUI()

        contentContainerView.addSubview(contentLabel)
        contentLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    override func render(_ post: Post) {
        super.render(post)

        contentLabel.text = switch post.content {
        case let .text(text):
            text
        default:
            ""
        }
    }
}

class VideoPostCell: PostBaseCell {
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.clipsToBounds = true
        return view
    }()
     
    override func setupUI() {
        super.setupUI()

        contentContainerView.addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.height.equalTo(containerView.snp.width).multipliedBy(9.0 / 16.0)
            make.edges.equalToSuperview()
        }
    }

    override func render(_ post: Post) {
        super.render(post)
        
        let item = PlaybackItem(mediaType: .video, contentString: post.content.contentString, tag: post.id)
        let hint = PlaybackHint(format: post.content.format, title: post.content.title)

        Task { @MainActor in
            await PlaybackService.shared.attachPlayer(to: containerView, with: item, hint: hint)
        }
    }
}

class AudioPostCell: PostBaseCell {
    private let containerView = UIView()
     
    override func setupUI() {
        super.setupUI()

        contentContainerView.addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.height.equalTo(33)
            make.edges.equalToSuperview()
        }
    }

    override func render(_ post: Post) {
        super.render(post)
        
        let item = PlaybackItem(mediaType: .audio, contentString: post.content.contentString, tag: post.id)
        let hint = PlaybackHint(format: post.content.format, title: post.content.title)

        Task { @MainActor in
            await PlaybackService.shared.attachPlayer(to: containerView, with: item, hint: hint)
        }
    }
}

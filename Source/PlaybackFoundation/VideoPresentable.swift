//
//  VideoPresentable.swift
//  Playback
//
//  Created by xueqooy on 2024/12/11.
//

import UIKit

public protocol VideoPresentable: UIView {
    var presentationSize: CGSize { set get }
    var coverImage: UIImage? { get set }
    var isCoverHidden: Bool { get set }
    var contentView: UIView? { get set }

    func loadCoverImage(from url: URL)
}

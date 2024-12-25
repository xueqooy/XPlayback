//
//  Extensions.swift
//  Playback
//
//  Created by xueqooy on 2022/12/27.
//

import UIKit
import XKit
import XUI

// Some extensions for internal use

extension UIView {
    /// Whether it is visible, if `findsCell` is true, meanwhile judge whether the cell located is visible in table view
    func isVisible(findsCell: Bool = false) -> Bool {
        let isSelfVisible = /* window != nil  &&*/ superview != nil && !isHidden && alpha > 0.0

        if !findsCell {
            return isSelfVisible
        }

        if isSelfVisible == false {
            return false
        }

        let cell = findCell()
        if let tableViewCell = cell as? UITableViewCell, let tableView = tableViewCell.tableView {
            return tableView.indexPath(for: tableViewCell) != nil
        } else if let collectionViewCell = cell as? UICollectionViewCell, let collectionView = collectionViewCell.collectionView {
            return collectionView.indexPath(for: collectionViewCell) != nil
        }

        return true
    }

    /// Recursively find the superview until it is UIScrollView
    func findScrollView() -> UIScrollView? {
        if let superview = superview {
            if let scrollView = superview as? UIScrollView {
                return scrollView
            }
            // Cell may not be added to the tableView/collectionView, which can be obtained through KVC.
            if let tableView = (superview as? UITableViewCell)?.tableView {
                return tableView
            }
            if let collectionView = (superview as? UICollectionViewCell)?.collectionView {
                return collectionView
            }
            return superview.findScrollView()
        }
        return nil
    }

    /// Recursively find the superview until it is UITableViewCell or UICollectionViewCell
    func findCell() -> UIView? {
        if let superview = superview {
            if let tableViewCell = superview as? UITableViewCell {
                return tableViewCell
            }
            if let collectionViewCell = superview as? UICollectionViewCell {
                return collectionViewCell
            }
            return superview.findCell()
        }
        return nil
    }
}

extension UITableViewCell {
    var tableView: UITableView? {
        if let tableView = value(forKey: "tableView") as? UITableView {
            return tableView
        }
        return nil
    }
}

extension UICollectionViewCell {
    var collectionView: UICollectionView? {
        if let tableView = value(forKey: "collectionView") as? UICollectionView {
            return tableView
        }
        return nil
    }
}

extension String {
    func firstMatch(pattern: String) -> String? {
        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        guard let result = regex?.firstMatch(in: self, range: NSRange(location: 0, length: (self as NSString).length)) else {
            return nil
        }
        return (self as NSString).substring(with: result.range)
    }
}

extension UIDeviceOrientation {
    func asInterfaceOrientation() -> UIInterfaceOrientation {
        UIInterfaceOrientation(rawValue: rawValue) ?? .unknown
    }
}

extension UIInterfaceOrientationMask {
    func contains(_ orientation: UIInterfaceOrientation) -> Bool {
        switch orientation {
        case .portrait:
            return contains(UIInterfaceOrientationMask.portrait)
        case .portraitUpsideDown:
            return contains(UIInterfaceOrientationMask.portraitUpsideDown)
        case .landscapeLeft:
            return contains(UIInterfaceOrientationMask.landscapeLeft)
        case .landscapeRight:
            return contains(UIInterfaceOrientationMask.landscapeRight)
        default:
            return false
        }
    }
}

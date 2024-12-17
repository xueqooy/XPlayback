//
//  Assets.swift
//  Playback
//
//  Created by xueqooy on 2024/12/2.
//

import Foundation
import XKit

class Assets {
    private static var bundle: Bundle { return Bundle(for: self) }

    private static let assetsBundle: Bundle = {
        guard let url = bundle.resourceURL?.appendingPathComponent("Playback_Assets.bundle", isDirectory: true),
              let bundle = Bundle(url: url)
        else {
            preconditionFailure("Playback assets bundle is not found")
        }
        return bundle
    }()

    static func image(named name: String) -> UIImage {
        guard let image = UIImage(named: name, in: assetsBundle, compatibleWith: nil) else {
            Logs.error("Missing image named \(name)", tag: "Playback")
            return .init()
        }

        return image
    }
}

//
//  UIImageView+NetworkImage.swift
//  Playback
//
//  Created by xueqooy on 2024/12/5.
//

import UIKit
import XKit
import XUI

private let latestTaskAssociation = Association<Task<Void, Error>>(wrap: .weak)

extension UIImageView {
    func setImage(with url: URL, placeholder: UIImage? = nil) {
        latestTaskAssociation[self]?.cancel()

        image = placeholder

        if url.isFileURL {
            loadImage(from: url)
        } else {
            let task = Task {
                let url = try await Downloader.default.download(.init(url: url, headers: ["Accept": "image/*"]))

                await MainActor.run { [weak self] in
                    guard let self else { return }

                    self.loadImage(from: url)
                }
            }

            latestTaskAssociation[self] = task
        }
    }

    private func loadImage(from fileURL: URL) {
        guard let data = try? Data(contentsOf: fileURL), let image = UIImage(data: data) else { return }

        let targetSize = Device.current.isPad ? CGSize(width: 750, height: 750) : CGSize(width: 500, height: 500)

        self.image = image.maybeScale(to: targetSize)
    }
}

private extension UIImage {
    func maybeScale(to targetSize: CGSize) -> UIImage {
        let size = self.size
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height

        let scaleFactor = min(widthRatio, heightRatio)

        guard scaleFactor < 1 else {
            return self
        }

        let newSize = CGSize(width: size.width * scaleFactor, height: size.height * scaleFactor)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        draw(in: CGRect(origin: .zero, size: newSize))
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return scaledImage ?? self
    }
}

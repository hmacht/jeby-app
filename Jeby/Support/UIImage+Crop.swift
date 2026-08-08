//
//  UIImage+Crop.swift
//  Jeby
//
//  Trimming a capture down to what the viewfinder actually showed.
//

import UIKit

extension UIImage {
    /// Center-crops to the given width-over-height ratio.
    ///
    /// The camera preview fills the screen, which means it shows a crop of the
    /// sensor's native 4:3. Applying the same crop to the capture is what makes
    /// "what you framed is what you get" true rather than approximately true.
    func cropped(toAspectRatio aspect: CGFloat) -> UIImage {
        guard aspect > 0, let source = normalized().cgImage else { return self }

        let width = CGFloat(source.width)
        let height = CGFloat(source.height)
        let current = width / height

        // Already the right shape, give or take a rounding error.
        guard abs(current - aspect) > 0.001 else { return self }

        let cropRect: CGRect
        if current > aspect {
            // Too wide: take a full-height slice out of the middle.
            let target = height * aspect
            cropRect = CGRect(x: ((width - target) / 2).rounded(), y: 0, width: target.rounded(), height: height)
        } else {
            // Too tall: take a full-width slice out of the middle.
            let target = width / aspect
            cropRect = CGRect(x: 0, y: ((height - target) / 2).rounded(), width: width, height: target.rounded())
        }

        guard let cropped = source.cropping(to: cropRect) else { return self }
        return UIImage(cgImage: cropped, scale: scale, orientation: .up)
    }

    /// Redraws the image with its orientation baked in, so pixel coordinates and
    /// visual coordinates agree. Cropping a CGImage ignores `imageOrientation`,
    /// which on a portrait photo means slicing the wrong axis entirely.
    private func normalized() -> UIImage {
        guard imageOrientation != .up else { return self }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

import UIKit

extension UIImage {
    func compositedOnWhiteBackground() -> UIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 1

        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIColor.white.setFill()
            UIBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

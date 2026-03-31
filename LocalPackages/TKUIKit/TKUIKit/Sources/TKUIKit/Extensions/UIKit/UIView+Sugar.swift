import UIKit

public extension UIView {
    func addSubviews(_ views: UIView...) {
        views.forEach { addSubview($0) }
    }

    func removeSubviews() {
        subviews.forEach { $0.removeFromSuperview() }
    }

    func heightThatFits(_ height: CGFloat) -> CGFloat {
        return sizeThatFits(CGSize(width: bounds.width, height: height)).height
    }
}

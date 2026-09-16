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

    var isReachableByUser: Bool {
        guard let window, !isHidden, alpha > 0.01, !bounds.isEmpty else {
            return false
        }

        let boundsCenter = CGPoint(x: bounds.midX, y: bounds.midY)
        let centerInWindow = convert(boundsCenter, to: window)
        guard let hitView = window.hitTest(centerInWindow, with: nil) else {
            return false
        }

        guard let owningView = nearestViewControllerView else {
            return hitView === self || hitView.isDescendant(of: self)
        }
        return hitView.isDescendant(of: owningView)
    }

    private var nearestViewControllerView: UIView? {
        var responder: UIResponder? = next
        while let current = responder {
            if let viewController = current as? UIViewController {
                return viewController.viewIfLoaded
            }
            responder = current.next
        }
        return nil
    }
}

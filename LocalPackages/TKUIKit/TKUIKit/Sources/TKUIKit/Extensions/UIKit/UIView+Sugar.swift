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

    /// Probed where a hint would point: a view scrolled out of its scroll view still counts while the user can
    /// scroll it back and its screen is on top.
    var isReachableByUser: Bool {
        guard let window, !isHidden, alpha > 0.01, !bounds.isEmpty else {
            return false
        }

        let anchor = hintAnchor(in: window)
        guard
            anchor.isRevealable,
            let hitView = window.hitTest(CGPoint(x: anchor.frame.midX, y: anchor.frame.midY), with: nil)
        else {
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

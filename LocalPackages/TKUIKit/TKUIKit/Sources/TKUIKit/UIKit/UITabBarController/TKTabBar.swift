import UIKit

final class TKTabBar: UITabBar {
    override func addSubview(_ view: UIView) {
        super.addSubview(view)
        guard !(view is TKTabBarView) else { return }
        takeOverSystemContent()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        takeOverSystemContent()
        tkTabBarController?.tabBarDidLayoutSubviews()
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        var sizeThatFits = super.sizeThatFits(size)

        sizeThatFits.height = .bottomOffset + .tabBarHeight

        return sizeThatFits
    }

    /// `TKTabBarView` draws the bar, but UIKit keeps laying out its own content underneath and
    /// it would otherwise take the touches, paint the previous selection's title, and show up
    /// twice in the accessibility tree. The selection platter is also drawn past the bar's own
    /// bounds, where no subview of ours can cover it, so the bar has to clip.
    private func takeOverSystemContent() {
        clipsToBounds = true
        guard let tabBarView = subviews.compactMap({ $0 as? TKTabBarView }).first else { return }
        for subview in subviews where subview !== tabBarView {
            subview.isHidden = true
            subview.isUserInteractionEnabled = false
            subview.accessibilityElementsHidden = true
        }
        bringSubviewToFront(tabBarView)
    }

    private var tkTabBarController: TKTabBarController? {
        var responder = next
        while let current = responder {
            if let controller = current as? TKTabBarController {
                return controller
            }
            responder = current.next
        }
        return nil
    }
}

private extension CGFloat {
    static let bottomOffset: CGFloat = 20
    static let tabBarHeight: CGFloat = 64
}

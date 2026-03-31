import UIKit

final class TKTabBar: UITabBar {
    override func layoutSubviews() {
        super.layoutSubviews()
        for subview in subviews {
            guard String(describing: type(of: subview)) == .tabBarButtonClassName else {
                continue
            }
            subview.frame.origin.y = .tabBarButtonYOffset
            subview.frame.size.height = .tabBarButtonHeight
        }
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        var sizeThatFits = super.sizeThatFits(size)

        sizeThatFits.height = .bottomOffset + .tabBarHeight

        return sizeThatFits
    }
}

private extension String {
    static let tabBarButtonClassName = "UITabBarButton"
}

private extension CGFloat {
    static let tabBarButtonYOffset: CGFloat = 8
    static let tabBarButtonHeight: CGFloat = 48
    static let bottomOffset: CGFloat = 20
    static let tabBarHeight: CGFloat = 64
}

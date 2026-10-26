import UIKit

final class TKSystemTabBar {
    private weak var controller: TKTabBarController?

    init(controller: TKTabBarController) {
        self.controller = controller
    }

    func install() {
        guard let controller else { return }
        let tabBar = controller.tabBar
        // Undo the custom bar's takeover without inserting anything of our own. The vertical
        // bar portals its buttons, so a subview added for an animation is mirrored into the
        // content and stays there after the device is folded or rotated.
        if tabBar is TKTabBar {
            object_setClass(tabBar, UITabBar.self)
            tabBar.clipsToBounds = false
            for subview in tabBar.subviews {
                subview.isHidden = false
                subview.isUserInteractionEnabled = true
                subview.accessibilityElementsHidden = false
            }
        }

        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        let itemAppearance = systemItemAppearance()
        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.unselectedItemTintColor = nil
        controller.view.setNeedsLayout()
    }

    func layoutSubviews() {
        controller?.didLayoutTabBar?()
    }

    private func systemItemAppearance() -> UITabBarItemAppearance {
        let itemAppearance = UITabBarItemAppearance()
        let inactive = UIColor.TabBar.inactiveIcon
        let active = UIColor.TabBar.activeIcon
        itemAppearance.normal.iconColor = inactive
        itemAppearance.normal.titleTextAttributes = titleAttributes(color: inactive)
        itemAppearance.selected.iconColor = active
        itemAppearance.selected.titleTextAttributes = titleAttributes(color: active)
        itemAppearance.focused.iconColor = active
        itemAppearance.focused.titleTextAttributes = titleAttributes(color: active)
        itemAppearance.disabled.iconColor = inactive
        itemAppearance.disabled.titleTextAttributes = titleAttributes(color: inactive)
        return itemAppearance
    }

    private func titleAttributes(color: UIColor) -> [NSAttributedString.Key: Any] {
        [
            .foregroundColor: color,
            .font: TKTextStyle.label3.font,
        ]
    }
}

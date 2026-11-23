import UIKit

public enum TKPopupMenuPosition {
    case top
    case topRight
    case bottomRight(inset: CGFloat)
    case bottomLeft(inset: CGFloat)
}

public enum TKPopupMenuController {
    private static var menuViewController: TKPopupMenuViewController?
    private weak static var sourceView: UIView?

    public static func show(
        sourceView: UIView,
        position: TKPopupMenuPosition,
        minimumWidth: CGFloat,
        items: [TKPopupMenuItem],
        isSelectable: Bool = true,
        selectedIndex: Int?
    ) {
        self.sourceView = sourceView
        guard let sourceWindow = sourceView.window else { return }

        let menuViewController = TKPopupMenuViewController()
        menuViewController.didSelectItem = {
            self.dismiss()
        }

        menuViewController.didTapToDismiss = {
            self.dismiss()
        }

        menuViewController.didChangeContainerSize = { [weak menuViewController] in
            guard let menuViewController, self.menuViewController === menuViewController else { return }
            self.dismiss()
        }

        sourceWindow.addSubview(menuViewController.view)
        menuViewController.view.frame = sourceWindow.bounds
        menuViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        menuViewController.showMenu(
            items: items,
            selectedIndex: selectedIndex,
            sourceView: sourceView,
            position: position,
            minimumWidth: minimumWidth,
            maximumWidth: .menuWidth,
            isSelectable: isSelectable,
            duration: .animationDuration
        )

        self.menuViewController = menuViewController
    }

    public static func dismiss() {
        // Once per menu: a second call while it hides does nothing, and the hide removes only its
        // own menu, never one shown after it.
        guard let menuViewController else { return }
        self.menuViewController = nil
        menuViewController.hideMenu(duration: .animationDuration) {
            menuViewController.view.removeFromSuperview()
        }
    }
}

private extension CGFloat {
    static var menuWidth: CGFloat {
        Swift.min(300, UIScreen.main.bounds.width - 16 * 2)
    }
}

private extension TimeInterval {
    static let animationDuration: TimeInterval = 0.3
}

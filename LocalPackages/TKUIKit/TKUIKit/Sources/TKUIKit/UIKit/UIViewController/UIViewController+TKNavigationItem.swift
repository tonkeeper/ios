import UIKit

public extension UIViewController {
    func setupBackButton() {
        navigationItem.setupBackButton { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
    }

    func setupSwipeDownButton(_ action: @escaping () -> Void) {
        navigationItem.setupSwipeDown {
            action()
        }
    }

    func setupLeftCloseButton(_ action: @escaping () -> Void) {
        if TKLiquidGlass.isEnabled {
            navigationItem.leftBarButtonItem = .liquidGlass(image: .TKUIKit.Icons.Size28.xmarkOutline, action: action)
            return
        }
        let closeButton = createCloseButton(action)
        navigationItem.leftBarButtonItem = .customView(closeButton, pinnedTo: .leading)
    }

    func setupRightCloseButton(_ action: @escaping () -> Void) {
        if TKLiquidGlass.isEnabled {
            navigationItem.rightBarButtonItem = .liquidGlass(image: .TKUIKit.Icons.Size28.xmarkOutline, action: action)
            return
        }
        let closeButton = createCloseButton(action)
        navigationItem.rightBarButtonItem = .customView(closeButton, pinnedTo: .trailing)
    }

    func createCloseButton(_ action: @escaping () -> Void) -> TKUIHeaderIconButton {
        let closeButton = TKUIHeaderIconButton()
        closeButton.configure(
            model: TKUIHeaderButtonIconContentView.Model(
                image: .TKUIKit.Icons.Size16.close
            )
        )
        closeButton.addTapAction {
            action()
        }
        closeButton.tapAreaInsets = UIEdgeInsets(top: -10, left: -10, bottom: -10, right: -10)
        return closeButton
    }
}

public extension UINavigationItem {
    func setupBackButton(action: @escaping () -> Void) {
        if TKLiquidGlass.isEnabled {
            leftBarButtonItem = .liquidGlass(image: .TKUIKit.Icons.Size28.chevronLeft, action: action)
            return
        }
        let backButton = TKUIHeaderIconButton()
        backButton.configure(
            model: TKUIHeaderButtonIconContentView.Model(
                image: .TKUIKit.Icons.Size16.chevronLeft
            )
        )

        backButton.addTapAction(action)

        backButton.tapAreaInsets = UIEdgeInsets(top: -10, left: -10, bottom: -10, right: -10)
        leftBarButtonItem = .customView(backButton, pinnedTo: .leading)
    }

    func setupSwipeDown(action: @escaping () -> Void) {
        if TKLiquidGlass.isEnabled {
            leftBarButtonItem = .liquidGlass(image: .TKUIKit.Icons.Size28.chevronDown, action: action)
            return
        }
        let backButton = TKUIHeaderIconButton()
        backButton.configure(
            model: TKUIHeaderButtonIconContentView.Model(
                image: .TKUIKit.Icons.Size16.chevronDown
            )
        )

        backButton.addTapAction(action)

        backButton.tapAreaInsets = UIEdgeInsets(top: -10, left: -10, bottom: -10, right: -10)
        leftBarButtonItem = .customView(backButton, pinnedTo: .leading)
    }
}

private extension UIBarButtonItem {
    /// A plain system item, so on iOS 26 the bar draws it in its own glass circle, as in the wallet
    /// navigation bar.
    static func liquidGlass(image: UIImage, action: @escaping () -> Void) -> UIBarButtonItem {
        let item = UIBarButtonItem(image: image, primaryAction: UIAction { _ in action() })
        item.tintColor = .Icon.primary
        return item
    }
}

import UIKit

public extension TKUINavigationBar {
    /// A factory button as a system bar item: the image it gets there and its action, which is handed
    /// the view a popup anchors to.
    struct SystemBarItem {
        var image: UIImage
        var accessibilityIdentifier: String?
        var action: (UIView) -> Void
    }

    static func createBackButton(action: @escaping () -> Void) -> TKUIHeaderIconButton {
        let button = TKUIHeaderIconButton()
        button.configure(
            model: TKUIHeaderButtonIconContentView.Model(
                image: .TKUIKit.Icons.Size16.chevronLeft
            )
        )

        button.addTapAction(action)
        button.systemBarItem = SystemBarItem(image: .TKUIKit.Icons.Size28.chevronLeft) { _ in action() }

        button.tapAreaInsets = UIEdgeInsets(
            top: -10,
            left: -10,
            bottom: -10,
            right: -10
        )
        return button
    }

    static func createSwipeDownButton(action: @escaping () -> Void) -> UIView {
        let button = TKUIHeaderIconButton()
        button.configure(
            model: TKUIHeaderButtonIconContentView.Model(
                image: .TKUIKit.Icons.Size16.chevronDown
            )
        )

        button.addTapAction(action)
        button.systemBarItem = SystemBarItem(image: .TKUIKit.Icons.Size28.chevronDown) { _ in action() }

        button.tapAreaInsets = UIEdgeInsets(
            top: -10,
            left: -10,
            bottom: -10,
            right: -10
        )
        return button
    }

    static func createCloseButton(action: @escaping () -> Void) -> UIView {
        let button = TKUIHeaderIconButton()
        button.configure(
            model: TKUIHeaderButtonIconContentView.Model(
                image: .TKUIKit.Icons.Size16.close
            )
        )

        button.addTapAction(action)
        button.systemBarItem = SystemBarItem(image: .TKUIKit.Icons.Size28.xmarkOutline) { _ in action() }

        button.tapAreaInsets = UIEdgeInsets(
            top: -10,
            left: -10,
            bottom: -10,
            right: -10
        )
        return button
    }

    static func createMoreButton(action: @escaping (UIView) -> Void) -> UIView {
        let button = TKUIHeaderIconButton()
        button.configure(
            model: TKUIHeaderButtonIconContentView.Model(
                image: .TKUIKit.Icons.Size16.ellipses
            )
        )

        button.addTapAction { [weak button] in
            guard let button else { return }
            action(button)
        }
        button.systemBarItem = SystemBarItem(image: .TKUIKit.Icons.Size28.ellipses, action: action)

        button.tapAreaInsets = UIEdgeInsets(
            top: -10,
            left: -10,
            bottom: -10,
            right: -10
        )
        return button
    }

    static func createButton(icon: UIImage, action: @escaping (UIView) -> Void) -> UIView {
        let button = TKUIHeaderIconButton()
        button.configure(
            model: TKUIHeaderButtonIconContentView.Model(
                image: icon
            )
        )

        button.addTapAction { [weak button] in
            guard let button else { return }
            action(button)
        }
        button.systemBarItem = SystemBarItem(image: icon, action: action)

        button.tapAreaInsets = UIEdgeInsets(
            top: -10,
            left: -10,
            bottom: -10,
            right: -10
        )
        return button
    }
}

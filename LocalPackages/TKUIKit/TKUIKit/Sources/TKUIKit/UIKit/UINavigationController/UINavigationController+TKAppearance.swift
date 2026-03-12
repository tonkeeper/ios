import UIKit

public extension UINavigationController {
    func configureDefaultAppearance() {
        navigationBar.configureDefaultAppearance()
    }

    func configureTransparentAppearance() {
        navigationBar.configureTransparentAppearance()
    }
}

public extension UINavigationBar {
    func configureDefaultAppearance() {
        guard !UIApplication.useSystemBarsAppearance else {
            UINavigationBar.appearance().titleTextAttributes = customTitleTextAttributes
            UINavigationBar.appearance().largeTitleTextAttributes = customLargeTitleTextAttributes
            return
        }

        func createAppearance() -> UINavigationBarAppearance {
            let standartAppearance = UINavigationBarAppearance()
            standartAppearance.configureWithOpaqueBackground()
            standartAppearance.backgroundColor = .Background.page
            standartAppearance.titleTextAttributes = customTitleTextAttributes
            standartAppearance.largeTitleTextAttributes = customLargeTitleTextAttributes
            return standartAppearance
        }

        let separatorAppearance = createAppearance()
        separatorAppearance.shadowColor = .Separator.common
        standardAppearance = separatorAppearance
    }

    func configureTransparentAppearance() {
        guard !UIApplication.useSystemBarsAppearance else {
            return
        }

        let navigationBarAppearance = UINavigationBarAppearance()
        navigationBarAppearance.configureWithTransparentBackground()

        standardAppearance = navigationBarAppearance
        compactAppearance = navigationBarAppearance
        if #available(iOS 15.0, *) {
            compactScrollEdgeAppearance = navigationBarAppearance
        }
    }
}

private extension UINavigationBar {
    var customTitleTextAttributes: [NSAttributedString.Key: Any] {
        [.foregroundColor: UIColor.Text.primary, .font: TKTextStyle.h3.font]
    }

    var customLargeTitleTextAttributes: [NSAttributedString.Key: Any] {
        [.foregroundColor: UIColor.Text.primary, .font: TKTextStyle.h1.font]
    }
}

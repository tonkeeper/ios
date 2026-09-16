import UIKit

public protocol TKThemeAppearance {
    var userInterfaceStyle: UIUserInterfaceStyle { get }
    func statusBarStyle(for userInterfaceStyle: UIUserInterfaceStyle) -> UIStatusBarStyle
    func colorScheme(for userInterfaceStyle: UIUserInterfaceStyle) -> TKColorScheme
}

struct DeepBlueThemeAppearance: TKThemeAppearance {
    var userInterfaceStyle: UIUserInterfaceStyle {
        .dark
    }

    func statusBarStyle(for userInterfaceStyle: UIUserInterfaceStyle) -> UIStatusBarStyle {
        .lightContent
    }

    func colorScheme(for userInterfaceStyle: UIUserInterfaceStyle) -> TKColorScheme {
        DeepBlueColorScheme()
    }
}

struct DarkThemeAppearance: TKThemeAppearance {
    var userInterfaceStyle: UIUserInterfaceStyle {
        .dark
    }

    func statusBarStyle(for userInterfaceStyle: UIUserInterfaceStyle) -> UIStatusBarStyle {
        .lightContent
    }

    func colorScheme(for userInterfaceStyle: UIUserInterfaceStyle) -> TKColorScheme {
        DarkColorScheme()
    }
}

struct LightThemeAppearance: TKThemeAppearance {
    var userInterfaceStyle: UIUserInterfaceStyle {
        .light
    }

    func statusBarStyle(for userInterfaceStyle: UIUserInterfaceStyle) -> UIStatusBarStyle {
        .darkContent
    }

    func colorScheme(for userInterfaceStyle: UIUserInterfaceStyle) -> TKColorScheme {
        LightColorScheme()
    }
}

struct SystemThemeAppearance: TKThemeAppearance {
    var userInterfaceStyle: UIUserInterfaceStyle {
        .unspecified
    }

    func statusBarStyle(for userInterfaceStyle: UIUserInterfaceStyle) -> UIStatusBarStyle {
        switch userInterfaceStyle {
        case .unspecified:
            return .darkContent
        case .light:
            return .darkContent
        case .dark:
            return .lightContent
        @unknown default:
            return .lightContent
        }
    }

    func colorScheme(for userInterfaceStyle: UIUserInterfaceStyle) -> TKColorScheme {
        switch userInterfaceStyle {
        case .unspecified:
            return LightColorScheme()
        case .light:
            return LightColorScheme()
        case .dark:
            return DarkColorScheme()
        @unknown default:
            return DarkColorScheme()
        }
    }
}

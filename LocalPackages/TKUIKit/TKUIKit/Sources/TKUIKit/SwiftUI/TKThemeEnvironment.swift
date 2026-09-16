import SwiftUI
import UIKit

/// The concrete color scheme (light/dark/deep blue) the current theme resolves
/// to; the single source of palette resolution for SwiftUI.
public enum TKResolvedTheme: Hashable, Sendable {
    case light
    case dark
    case deepBlue

    public init(theme: TKTheme, systemColorScheme: SwiftUI.ColorScheme) {
        self.init(theme: theme, isSystemDark: systemColorScheme == .dark)
    }

    public init(theme: TKTheme, isSystemDark: Bool) {
        switch theme {
        case .light:
            self = .light
        case .dark:
            self = .dark
        case .deepBlue:
            self = .deepBlue
        case .system:
            self = isSystemDark ? .dark : .light
        }
    }

    var colorScheme: TKColorScheme {
        switch self {
        case .light:
            LightColorScheme()
        case .dark:
            DarkColorScheme()
        case .deepBlue:
            DeepBlueColorScheme()
        }
    }

    public var palette: TKPalette {
        switch self {
        case .light:
            Self.lightPalette
        case .dark:
            Self.darkPalette
        case .deepBlue:
            Self.deepBluePalette
        }
    }

    private static let lightPalette = TKPalette(resolvedTheme: .light)
    private static let darkPalette = TKPalette(resolvedTheme: .dark)
    private static let deepBluePalette = TKPalette(resolvedTheme: .deepBlue)
}

private struct TKResolvedThemeKey: EnvironmentKey {
    /// Correct at first render for previews and roots without `.tkThemed()`;
    /// non-reactive until a provider is installed above.
    static var defaultValue: TKResolvedTheme {
        TKResolvedTheme(
            theme: TKThemeManager.shared.theme,
            isSystemDark: UIScreen.main.traitCollection.userInterfaceStyle == .dark
        )
    }
}

public extension EnvironmentValues {
    var tkResolvedTheme: TKResolvedTheme {
        get { self[TKResolvedThemeKey.self] }
        set { self[TKResolvedThemeKey.self] = newValue }
    }

    /// Derived from `tkResolvedTheme` so the two can never disagree.
    var tkPalette: TKPalette {
        tkResolvedTheme.palette
    }
}

private struct TKThemeProviderModifier: ViewModifier {
    @ObservedObject private var themeManager = TKThemeManager.shared
    @Environment(\.colorScheme) private var systemColorScheme

    func body(content: Content) -> some View {
        content
            .environment(
                \.tkResolvedTheme,
                TKResolvedTheme(theme: themeManager.theme, systemColorScheme: systemColorScheme)
            )
    }
}

public extension View {
    func tkThemed() -> some View {
        modifier(TKThemeProviderModifier())
    }
}

public struct TKThemedView<Content: View>: View {
    public var content: Content

    public init(content: Content) {
        self.content = content
    }

    public var body: some View {
        content.tkThemed()
    }
}

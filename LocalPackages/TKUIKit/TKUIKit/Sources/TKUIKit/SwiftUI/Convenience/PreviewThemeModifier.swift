import SwiftUI

extension TKPreview {
    static func pinTheme(_ theme: TKTheme) {
        TKThemeManager.shared.applyPreviewTheme(theme)
    }
}

public extension View {
    func tkPreviewTheme(_ theme: TKResolvedTheme) -> some View {
        modifier(PreviewThemeModifier(theme: theme))
    }
}

struct PreviewThemeModifier: ViewModifier {
    private let theme: TKResolvedTheme

    init(theme: TKResolvedTheme) {
        self.theme = theme
        TKPreview.pinTheme(theme.theme)
    }

    func body(content: Content) -> some View {
        content
            .environment(\.tkResolvedTheme, theme)
            .environment(\.colorScheme, theme == .light ? .light : .dark)
    }
}

private extension TKResolvedTheme {
    var theme: TKTheme {
        switch self {
        case .light:
            .light
        case .dark:
            .dark
        case .deepBlue:
            .deepBlue
        }
    }
}

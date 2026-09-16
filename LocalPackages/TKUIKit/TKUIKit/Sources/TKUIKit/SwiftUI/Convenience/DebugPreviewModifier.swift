import SwiftUI
import UIKit

/// Colors for `#Preview` blocks and preview sample data, where the SwiftUI
/// environment is unavailable. Resolved once per render; in-app views must use
/// `@Environment(\.tkPalette)` instead.
@MainActor
enum TKPreview {
    static var palette: TKPalette {
        TKResolvedTheme(
            theme: TKThemeManager.shared.theme,
            isSystemDark: UIScreen.main.traitCollection.userInterfaceStyle == .dark
        ).palette
    }
}

enum DebugPreviewBackground {
    case content
    case page
}

extension View {
    func debugPreview(
        background: DebugPreviewBackground = .content
    ) -> some View {
        modifier(DebugPreviewModifier(background: background))
    }
}

struct DebugPreviewModifier: ViewModifier {
    @Environment(\.tkPalette) private var palette

    var background: DebugPreviewBackground

    func body(content: Content) -> some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()

            content
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .center
                )
        }
    }

    private var backgroundColor: Color {
        switch background {
        case .content:
            palette.background.content
        case .page:
            palette.background.page
        }
    }
}

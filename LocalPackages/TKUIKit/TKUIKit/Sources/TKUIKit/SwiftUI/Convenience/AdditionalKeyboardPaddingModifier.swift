import SwiftUI
import UIKit

public extension View {
    /// Extra bottom inset applied while the keyboard is visible, so the automatic
    /// keyboard avoidance keeps the focused field this much higher than by default.
    func tkAdditionalKeyboardPadding(_ padding: CGFloat) -> some View {
        modifier(AdditionalKeyboardPaddingModifier(padding: padding))
    }
}

private struct AdditionalKeyboardPaddingModifier: ViewModifier {
    let padding: CGFloat

    @State private var isKeyboardVisible = false

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if isKeyboardVisible {
                    Color.clear
                        .frame(height: padding)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                withAnimation(.easeOut(duration: Const.animationDuration)) {
                    isKeyboardVisible = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(.easeOut(duration: Const.animationDuration)) {
                    isKeyboardVisible = false
                }
            }
    }

    private enum Const {
        static let animationDuration: CGFloat = 0.25
    }
}

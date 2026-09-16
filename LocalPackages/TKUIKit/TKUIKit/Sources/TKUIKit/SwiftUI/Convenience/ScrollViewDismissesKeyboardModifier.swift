import SwiftUI

public extension View {
    /// `.scrollDismissesKeyboard(.interactively)` on iOS 16+, no-op on earlier versions.
    @ViewBuilder
    func tkDismissesKeyboardInteractively() -> some View {
        if #available(iOS 16.0, *) {
            scrollDismissesKeyboard(.interactively)
        } else {
            self
        }
    }
}

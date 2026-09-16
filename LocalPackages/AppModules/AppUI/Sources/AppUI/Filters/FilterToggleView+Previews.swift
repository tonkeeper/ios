import SwiftUI
import TKUIKit

@available(iOS 17.0, *)
#Preview("States", traits: .sizeThatFitsLayout) {
    FilterToggleView(
        items: [
            FilterToggleItem(
                title: "Hide tiny transfers",
                subtitle: "Transfers worth less than $0.01.",
                isOn: true,
                onToggle: { _ in }
            ),
            FilterToggleItem(
                title: "Hide risky trades",
                subtitle: "Trades involving suspicious tokens or contracts.",
                isOn: false,
                onToggle: { _ in }
            ),
        ]
    )
    .padding(.vertical)
    .background(.backgroundPage)
    .tkPreviewTheme(.deepBlue)
}

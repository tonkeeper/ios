import SwiftUI
import TKUIKit

private struct AmountFieldPreview: View {
    let text: String
    let caption: String
    var isValid = true
    @FocusState private var focus: Bool

    var body: some View {
        BatteryAmountField(
            placeholder: "Amount in USD₮",
            text: .constant(text),
            caption: caption,
            isValid: isValid,
            isFocused: $focus,
            accessibilityIdentifier: "battery_refill_amount"
        )
        .padding([.top, .horizontal], 16)
        .padding(.bottom, 16)
        .background(.backgroundPage)
    }
}

@available(iOS 17.0, *)
#Preview("Amount", traits: .fixedLayout(width: 390, height: 128)) {
    AmountFieldPreview(text: "1.2", caption: "≈ 1 158 charges · Available 3 906 USD₮")
        .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("Amount · below minimum", traits: .fixedLayout(width: 390, height: 128)) {
    AmountFieldPreview(text: "0.1", caption: "Minimum 1 USD₮", isValid: false)
        .tkPreviewTheme(.deepBlue)
}

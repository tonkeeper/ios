import SwiftUI
import TKLocalize
import TKUIKit

private struct RechargePreview: View {
    let symbol: String
    var custom = true
    var isValid = true
    var isBusy = false
    @FocusState private var focus: Bool

    var body: some View {
        BatteryRechargeForm(state: .init(title: TKLocales.Battery.Recharge.title, symbol: symbol, image: .url(nil), packs: [
            .init(id: "large", title: "5.29 " + symbol, caption: "2 500 charges", icon: .fill(1), tag: TKLocales.Battery.Refill.bestValue),
            .init(id: "medium", title: "3.53 " + symbol, caption: "1 500 charges", icon: .fill(0.6), isSelected: !custom),
            .init(id: "small", title: "1.76 " + symbol, caption: "750 charges", icon: .fill(0.3)),
            .init(id: "custom", title: TKLocales.Battery.Recharge.СustomInput.title, caption: TKLocales.Battery.Recharge.СustomInput.caption, icon: .other, isSelected: custom),
        ], showsAmount: custom, isEnabled: isValid, isBusy: isBusy), onSelectPack: { _ in }, onSelectAsset: {}, onContinue: {}, onClose: {}, endEditing: {}, amount: {
            BatteryAmountField(
                placeholder: TKLocales.Battery.Refill.amountPlaceholder(symbol),
                text: .constant(isValid ? "1.2" : "0.01"),
                caption: isValid ? "≈ 1 158 charges · Available 2.4 " + symbol : "Minimum 0.1 " + symbol,
                isValid: isValid,
                isFocused: $focus,
                accessibilityIdentifier: "battery_recharge_amount"
            )
        }, promo: {
            TKInputField(placeholder: TKLocales.Battery.Refill.promocode, text: .constant(""), isValid: true, isFocused: $focus) {
                ButtonView(config: .init(title: TKLocales.Actions.paste, size: .small, appearance: .tertiary, action: {}))
                    .frame(height: 24)
            }
        }, recipient: { EmptyView() })
    }
}

private struct RechargeSheetPreview: View {
    var custom = false
    var isValid = true
    var isBusy = false
    @State private var isPresented = true

    var body: some View {
        TKColor.backgroundPage.ignoresSafeArea()
            .sheet(isPresented: $isPresented) {
                RechargePreview(symbol: "tsTON", custom: custom, isValid: isValid, isBusy: isBusy)
                    .tkPreviewTheme(.deepBlue)
            }
            .id("\(custom)-\(isValid)-\(isBusy)")
            .transaction { $0.disablesAnimations = true }
    }
}

#Preview("TON custom") {
    RechargePreview(symbol: "TON").tkPreviewTheme(.dark)
}

#Preview("EVM custom") {
    RechargePreview(symbol: "ETH").tkPreviewTheme(.light)
}

#Preview("Solana custom") {
    RechargePreview(symbol: "USDC").tkPreviewTheme(.deepBlue)
}

#Preview("Other tokens · Package") {
    RechargeSheetPreview().tkPreviewTheme(.deepBlue)
}

#Preview("Other tokens · Custom amount") {
    RechargeSheetPreview(custom: true).tkPreviewTheme(.deepBlue)
}

#Preview("Other tokens · Below minimum") {
    RechargeSheetPreview(custom: true, isValid: false).tkPreviewTheme(.deepBlue)
}

#Preview("Other tokens · Preparing") {
    RechargeSheetPreview(isBusy: true).tkPreviewTheme(.deepBlue)
}

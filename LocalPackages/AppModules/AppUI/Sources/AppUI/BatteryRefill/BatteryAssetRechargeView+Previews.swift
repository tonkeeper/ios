import SwiftUI
import TKLocalize
import TKUIKit

private func previewState(confirmation: Bool = false, terminal: Bool = false, message: String? = nil, canRetry: Bool = false) -> BatteryAssetRechargeViewState {
    .init(
        title: TKLocales.Battery.Refill.Crypto.recharge + " SOL",
        network: "Solana",
        image: .url(nil),
        input: .init(text: "0.0312", symbol: .text("SOL"), converted: nil, balance: .init(text: "0.0019 SOL", showsMax: false)),
        charges: "750 " + TKLocales.Battery.Refill.chargesCount(count: 750),
        fiat: "≈ $2.40",
        fee: "21 " + TKLocales.Battery.Refill.chargesCount(count: 21),
        message: message,
        isConfirmation: confirmation,
        canRetry: canRetry,
        isEnabled: !canRetry,
        isTerminal: terminal
    )
}

#Preview("Amount") {
    BatteryAssetRechargeView(state: previewState(), onAmount: { _ in }, onContinue: {}, onClose: {}, onRetry: {}, onEdit: {})
        .tkPreviewTheme(.dark)
}

#Preview("Confirm") {
    BatteryAssetRechargeView(state: previewState(confirmation: true), onAmount: { _ in }, onContinue: {}, onClose: {}, onRetry: {}, onEdit: {})
        .tkPreviewTheme(.light)
}

#Preview("Quote changed") {
    BatteryAssetRechargeView(state: previewState(confirmation: true, message: TKLocales.Battery.Purchase.quoteChanged), onAmount: { _ in }, onContinue: {}, onClose: {}, onRetry: {}, onEdit: {})
        .tkPreviewTheme(.deepBlue)
}

#Preview("Offline confirmation") {
    BatteryAssetRechargeView(state: previewState(confirmation: true, message: TKLocales.Multichain.Transaction.Error.failedToPrepare), onAmount: { _ in }, onContinue: {}, onClose: {}, onRetry: {}, onEdit: {})
        .tkPreviewTheme(.deepBlue)
}

#Preview("Preparation failed") {
    BatteryAssetRechargeView(state: previewState(confirmation: true, message: TKLocales.Multichain.Transaction.Error.failedToPrepare, canRetry: true), onAmount: { _ in }, onContinue: {}, onClose: {}, onRetry: {}, onEdit: {})
        .tkPreviewTheme(.deepBlue)
}

#Preview("Outcome unknown") {
    BatteryAssetRechargeView(state: previewState(confirmation: true, terminal: true, message: TKLocales.Battery.Purchase.outcomeUnknown), onAmount: { _ in }, onContinue: {}, onClose: {}, onRetry: {}, onEdit: {})
        .tkPreviewTheme(.dark)
}

#Preview("USDT Ethereum confirmation") {
    BatteryAssetRechargeView(state: .init(
        title: "Recharge with USDT", network: "Ethereum", image: .url(nil),
        input: .init(text: "2.207834", symbol: .text("USDT"), converted: nil, balance: .init(text: "Balance 4.66061 USDT", showsMax: false)),
        charges: "672 charges", fiat: "≈ $2.2", fee: "78 charges", isConfirmation: true, isEnabled: true
    ), onAmount: { _ in }, onContinue: {}, onClose: {}, onRetry: {}, onEdit: {})
        .tkPreviewTheme(.deepBlue)
}

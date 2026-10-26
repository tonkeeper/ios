import SwiftUI
import TKUIKit

private func action(_ kind: ConfirmActionBarState.Kind = .slider(title: "Slide to confirm", subtitle: "or tap and hold")) -> ConfirmActionBarState {
    ConfirmActionBarState(kind: kind, isEnabled: true, successTitle: "Done", failureTitle: "Error", onConfirm: {})
}

private let sendState = ConfirmActionState(
    header: .avatar(.image(.TKUIKit.Icons.Size28.ton, chainIcon: nil)),
    caption: "Confirm Action",
    title: "Transfer USDT",
    titleSuffix: "TRC20",
    rows: [
        ConfirmActionRow(id: "wallet", title: "Wallet", value: .wallet(name: "Main", emoji: "🙃", icon: nil)),
        ConfirmActionRow(id: "recipient", title: "Recipient", value: .text("UQBh…ZzEb"), interaction: .hint("UQBhXq7p4mJvD0rE1mK9z0kF2rQzZzEb")),
        ConfirmActionRow(id: "amount", title: "Amount", value: .text("120 USDT", subtitle: "$120.00")),
        ConfirmActionRow(id: "fee", title: "Fee", value: .feeOption("≈ $0.03", token: "TRX", showsPicker: true), interaction: .tap {}),
        ConfirmActionRow(id: "comment", title: "Comment", value: .text("Thanks for dinner")),
    ],
    action: action()
)

private let loadingState = ConfirmActionState(
    header: .letter("U"),
    caption: "Confirm Action",
    title: "Transfer USDC",
    rows: [
        ConfirmActionRow(id: "amount", title: "Amount", value: .text("713.01 USDC", subtitle: "$712.87")),
        ConfirmActionRow(id: "fee", title: "Fee", value: .loading),
    ],
    action: action(.button(title: "Confirm and Send"))
)

private let failedFeeState = ConfirmActionState(
    header: .letter("U"),
    caption: "Confirm Action",
    title: "Deposit USDC",
    titleSuffix: "Ethereum",
    rows: [
        ConfirmActionRow(id: "total", title: "Total amount", value: .parts([
            .init(text: "$120", tone: .tertiary),
            .init(text: " → ", tone: .tertiary),
            .init(text: "$95", tone: .primary),
        ])),
        ConfirmActionRow(id: "autoClose", title: "Auto close", value: .text("Off"), interaction: .tap({}, showsChevron: true)),
        ConfirmActionRow(id: "fee", title: "Network fee", value: .unavailable("Unavailable", retryTitle: "Retry", retry: {})),
    ],
    notice: .init(text: "Not enough ETH to pay the network fee.", isError: true),
    action: action()
)

#Preview("Send") {
    ConfirmActionView(state: sendState, onBack: {}, onClose: {})
        .tkPreviewTheme(.deepBlue)
}

#Preview("Fee loading, button") {
    ConfirmActionView(state: loadingState, onBack: nil, onClose: {})
        .tkPreviewTheme(.deepBlue)
}

#Preview("Fee failed, notice") {
    ConfirmActionView(state: failedFeeState, onBack: {}, onClose: {})
        .tkPreviewTheme(.light)
}

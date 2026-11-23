import SwiftUI
import TKLocalize
import TKUIKit

#Preview("Pending") {
    MultichainSwapDetailsView(
        state: .preview(status: .pending, transactions: [.sent, .receiving]),
        onClose: {},
        onOpenTransaction: { _, _ in },
        onCopyTransactionHash: { _ in }
    )
    .tkPreviewTheme(.deepBlue)
}

#Preview("Done") {
    MultichainSwapDetailsView(
        state: .preview(status: .done, transactions: [.sent, .received]),
        onClose: {},
        onOpenTransaction: { _, _ in },
        onCopyTransactionHash: { _ in }
    )
    .tkPreviewTheme(.deepBlue)
}

#Preview("Failed") {
    MultichainSwapDetailsView(
        state: .preview(status: .failed, transactions: [.sent]),
        onClose: {},
        onOpenTransaction: { _, _ in },
        onCopyTransactionHash: { _ in }
    )
    .tkPreviewTheme(.deepBlue)
}

private extension MultichainSwapDetailsViewState {
    static func preview(status: Status, transactions: [Transaction]) -> MultichainSwapDetailsViewState {
        MultichainSwapDetailsViewState(
            send: Amount(value: "100 GRAM", avatarSource: .image(.TKUIKit.Icons.Size44.tonLogo)),
            receive: Amount(value: "0.00181 BTC", avatarSource: .image(.TKUIKit.Icons.Size44.tonLogo)),
            date: "28 Sep 2026, 17:39",
            networkFee: "7 charges",
            status: status,
            transactions: transactions
        )
    }
}

private extension MultichainSwapDetailsViewState.Transaction {
    static let sent = link(title: TKLocales.ActionTypes.sent, hash: "4d1e1608")
    static let received = link(title: TKLocales.ActionTypes.received, hash: "9b7c3e52")

    static func link(title: String, hash: String) -> Self {
        .link(
            MultichainTransactionDetailsModel.TransactionButton(
                title: TKThemedText(spans: [
                    .init("\(title) ", color: .buttonSecondaryForeground),
                    .init(hash, color: .textTertiary),
                ]),
                url: URL(fileURLWithPath: "/"),
                browserTitle: nil
            ),
            hash: hash
        )
    }
}

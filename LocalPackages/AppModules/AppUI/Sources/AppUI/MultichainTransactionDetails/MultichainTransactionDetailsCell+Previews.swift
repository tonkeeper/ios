import SwiftUI
import TKUIKit

@available(iOS 17.0, *)
#Preview("Rows", traits: .fixedLayout(width: 390, height: 400)) {
    VStack(spacing: 0) {
        MultichainTransactionDetailsCell(
            content: .address(
                type: "Recipient Address",
                address: "UQF1eGnRj2WuIAulI...t41JTu43sWeG2IZ"
            ),
            showsDivider: true
        )
        MultichainTransactionDetailsCell(
            content: .network(
                title: "Network",
                name: TKThemedText(spans: [
                    .init("Ethereum ", color: .textPrimary),
                    .init("\u{2192} ", color: .textSecondary),
                    .init("TON", color: .textPrimary),
                ]),
                type: "ERC20"
            ),
            showsDivider: true
        )
        MultichainTransactionDetailsCell(
            content: .fee(title: "Network fee", amount: "0.0074 TON", fiatAmount: "$ 0.03"),
            showsDivider: true
        )
        MultichainTransactionDetailsCell(
            content: .txHash(
                title: "Tx hash",
                hash: "9vv7QcJ3fLxKk1gGqR7hSy4mNvB2dPzXwT8uHcAe5rBdZq"
            ),
            showsDivider: true
        )
        MultichainTransactionDetailsCell(
            content: .comment(title: "Comment", value: "Thanks!")
        )
    }
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    .padding(16)
    .background(.backgroundPage)
    .tkPreviewTheme(.deepBlue)
}

import SwiftUI
import TKUIKit

private extension MoonPayPaymentMethodViewState {
    static let mock = MoonPayPaymentMethodViewState(
        title: "Payment method",
        sections: [
            .init(
                id: "cash",
                title: "Cash",
                rows: [
                    .init(
                        id: "apple_pay",
                        title: "Apple Pay",
                        subtitle: "Instant",
                        iconURL: nil,
                        badge: "Recommended",
                        trailing: .checkmark
                    ),
                    .init(
                        id: "debit_card",
                        title: "Debit Card",
                        subtitle: "Add a new card",
                        iconURL: nil,
                        trailing: .none
                    ),
                    .init(
                        id: "revolut",
                        title: "Revolut Pay",
                        subtitle: "Instant",
                        iconURL: nil,
                        badge: "Recommended",
                        trailing: .none
                    ),
                    .init(
                        id: "paypal",
                        title: "PayPal",
                        subtitle: "Instant",
                        iconURL: nil,
                        badge: "Recommended",
                        trailing: .none
                    ),
                    .init(
                        id: "p2p",
                        title: "P2P Express",
                        subtitle: "Buy from other users in Wallet",
                        iconURL: nil,
                        badge: "For beginners",
                        trailing: .none
                    ),
                ]
            ),
        ],
        cryptoSection: .init(
            title: "Crypto",
            content: SetupCellContent(
                icon: .init(
                    image: .TKUIKit.Icons.Size28.qrCode,
                    tintColor: .accentBlue,
                    backgroundColor: .accentBlue.opacity(0.16)
                ),
                title: "Crypto deposit",
                titleTextStyle: .label1,
                subtitle: .init(text: "From another wallet"),
                accessory: .chevron
            )
        )
    )
}

@available(iOS 17.0, *)
#Preview("Payment method") {
    MoonPayPaymentMethodView(state: .mock, onSelect: { _ in }, onClose: {})
        .tkPreviewTheme(.deepBlue)
}

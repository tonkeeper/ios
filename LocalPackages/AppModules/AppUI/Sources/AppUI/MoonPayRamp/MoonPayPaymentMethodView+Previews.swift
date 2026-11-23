import SwiftUI
import TKUIKit

private extension MoonPayPaymentMethodViewState {
    static let cardMenu: [MenuItem] = [
        .init(id: "remove", title: "Remove", icon: .TKUIKit.Icons.Size28.trashBin),
    ]

    static let mock = MoonPayPaymentMethodViewState(
        title: "Payment method",
        provider: .init(caption: "via", name: "MoonPay", isSwitchable: true),
        sections: [
            .init(
                id: "saved",
                title: "Saved",
                rows: [
                    .init(
                        id: "card:1",
                        title: "Debit card",
                        subtitle: "Visa •••• 4148",
                        iconURL: nil,
                        savedCard: MoonPaySavedCardIcon(brand: "Visa", last4: "4148"),
                        badge: "Last used",
                        subtitleSuffix: .init(text: "Exp. 10/28", style: .neutral),
                        trailing: .none,
                        menu: cardMenu
                    ),
                    .init(
                        id: "card:2",
                        title: "Debit card",
                        subtitle: "Mastercard •••• 7482",
                        iconURL: nil,
                        savedCard: MoonPaySavedCardIcon(brand: "Mastercard", last4: "7482"),
                        subtitleSuffix: .init(text: "Expired 11/24", style: .error),
                        isEnabled: false,
                        trailing: .none,
                        menu: cardMenu
                    ),
                ]
            ),
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

// A lone tappable card is drawn in the group's single-cell mode, which pads the cell itself.
@available(iOS 17.0, *)
#Preview("One saved card") {
    var state = MoonPayPaymentMethodViewState.mock
    state.sections[0].rows = Array(state.sections[0].rows.prefix(1))
    return MoonPayPaymentMethodView(state: state, onSelect: { _ in }, onClose: {})
        .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("Loading another provider") {
    var state = MoonPayPaymentMethodViewState.mock
    state.isLoading = true
    return MoonPayPaymentMethodView(state: state, onSelect: { _ in }, onClose: {})
        .tkPreviewTheme(.deepBlue)
}

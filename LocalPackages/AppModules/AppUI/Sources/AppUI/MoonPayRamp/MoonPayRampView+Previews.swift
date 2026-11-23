import SwiftUI
import TKUIKit

private struct MoonPayRampPreview: View {
    let state: MoonPayRampViewState
    @FocusState private var focused: Bool

    var body: some View {
        MoonPayRampView(
            state: state,
            focus: $focused,
            onTextChange: { _ in },
            onQuickOption: { _ in },
            onConvertedTap: {},
            onCurrencyTap: {},
            onToggleRateDirection: {},
            onRateTimerCompleted: {},
            onPaymentMethodTap: {},
            onAction: {},
            onClose: {}
        )
    }
}

private extension MoonPayRampViewState {
    static let usd = MoonPayRampViewState(
        title: "Buy crypto",
        payInCaption: "Pay in",
        currencyCode: "USD",
        currencyImageURL: URL(string: "https://tonkeeper.com/assets/currencies/USD.png"),
        amount: AmountInputSheetState(
            text: "100",
            symbol: .text("USD"),
            converted: .init(
                text: "92.54",
                symbol: .text("USDT (TON)"),
                showsSwitchIcon: false,
                isSwitchEnabled: false,
                showsChevron: true,
                leadingImage: .TKUIKit.Icons.Size20.cryptoUsdt,
                leadingChainImage: .TKUIKit.Icons.Size20.tonChain,
                highlightsAmount: true
            ),
            quickOptions: [
                .init(id: "100", title: "$100", isSelected: false),
                .init(id: "200", title: "$200", isSelected: false),
                .init(id: "1000", title: "$1\u{00A0}000", isSelected: false),
            ],
            balance: nil
        ),
        rateText: "1 USD ≈ 1.002 USDT (TON)",
        rateRestartToken: 0,
        priceDetailsTitle: "incl. fees",
        payment: .init(title: "Apple Pay", subtitle: "Instant", iconURL: nil, badge: .moonPay),
        actionTitle: "Continue"
    )

    static let eur = MoonPayRampViewState(
        title: "Buy crypto",
        payInCaption: "Pay in",
        currencyCode: "EUR",
        currencyImageURL: URL(string: "https://tonkeeper.com/assets/currencies/EUR.png"),
        amount: AmountInputSheetState(
            text: "38 500",
            symbol: .text("EUR"),
            converted: .init(
                text: "0.4869",
                symbol: .text("BTC"),
                showsSwitchIcon: false,
                isSwitchEnabled: false,
                showsChevron: true,
                leadingImage: .TKUIKit.Icons.Size20.cryptoBtc,
                highlightsAmount: true
            ),
            quickOptions: [
                .init(id: "50", title: "€50", isSelected: false),
                .init(id: "100", title: "€100", isSelected: false),
                .init(id: "500", title: "€500", isSelected: false),
            ],
            balance: nil
        ),
        rateText: "1 BTC ≈ €74 600",
        rateRestartToken: 0,
        payment: .init(
            title: "Debit card",
            subtitle: "Visa •••• 4148",
            iconURL: nil,
            savedCard: MoonPaySavedCardIcon(brand: "Visa", last4: "4148"),
            badge: .moonPay
        ),
        actionTitle: "Continue"
    )

    static let noPaymentMethods = MoonPayRampViewState(
        title: "Buy crypto",
        payInCaption: "Pay in",
        currencyCode: "CLP",
        currencyImageURL: nil,
        amount: AmountInputSheetState(
            text: "0",
            symbol: .text("CLP"),
            converted: .init(
                text: "0",
                symbol: .text("BTC"),
                showsSwitchIcon: false,
                isSwitchEnabled: false,
                showsChevron: true,
                leadingImage: .TKUIKit.Icons.Size20.cryptoBtc,
                highlightsAmount: true
            ),
            quickOptions: [],
            balance: nil
        ),
        rateText: "",
        rateRestartToken: 0,
        payment: .init(title: "", subtitle: "", iconURL: nil),
        actionTitle: "Continue",
        placeholder: .init(
            title: "No payment methods",
            subtitle: "Buying with Chilean peso (CLP) isn't available right now. Choose another currency or deposit crypto from another wallet.",
            changeCurrencyTitle: "Change currency",
            cryptoDepositTitle: "Crypto deposit"
        )
    )
}

@available(iOS 17.0, *)
#Preview("USD") {
    MoonPayRampPreview(state: .usd)
        .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("EUR") {
    MoonPayRampPreview(state: .eur)
        .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("No payment methods") {
    MoonPayRampPreview(state: .noPaymentMethods)
        .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("Loading") {
    var state = MoonPayRampViewState.usd
    state.isLoading = true
    state.amount.converted?.isLoading = true
    state.rateText = ""
    return MoonPayRampPreview(state: state)
        .tkPreviewTheme(.deepBlue)
}

#Preview("EUR, disclosure") {
    var state = MoonPayRampViewState.eur
    state.disclosures = [
        (try? AttributedString(markdown: "By continuing, you agree to transact with MoonPay Europe, subject to its [Terms of Use](https://www.moonpay.com/legal/terms) and [Privacy Policy](https://www.moonpay.com/legal/privacy_policy). Crypto-assets can be risky and values may decrease quickly. Transfers are irreversible once broadcast to the blockchain. The quoted exchange rate may include a spread. [Learn more](https://www.moonpay.com/legal) and [review the whitepaper](https://dev.moonpay.com/docs/list-of-supported-cryptocurrencies) (if available).")) ?? "",
    ]
    return MoonPayRampPreview(state: state)
        .tkPreviewTheme(.deepBlue)
}

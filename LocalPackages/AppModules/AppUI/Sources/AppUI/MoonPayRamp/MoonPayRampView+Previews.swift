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
                leadingImage: .TKUIKit.Icons.Size20.cryptoUsdt
            ),
            quickOptions: [
                .init(id: "50", title: "$50", isSelected: false),
                .init(id: "100", title: "$100", isSelected: true),
                .init(id: "500", title: "$500", isSelected: false),
            ],
            balance: nil
        ),
        rateText: "1 USD ≈ 1.002 USDT (TON)",
        rateRestartToken: 0,
        payment: .init(title: "Apple Pay", subtitle: "Instant", iconURL: nil),
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
                leadingImage: .TKUIKit.Icons.Size20.cryptoBtc
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
        payment: .init(title: "Card", subtitle: "Instant", iconURL: nil),
        actionTitle: "Continue"
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

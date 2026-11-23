import SwiftUI
import TKLocalize
import TKUIKit
import WidgetKit

extension BalanceWidgetState {
    static func preview(hidesAmounts: Bool = false) -> Self {
        BalanceWidgetState(
            wallet: WidgetPreviewData.wallet,
            total: hidesAmounts ? nil : "$8 245.60",
            totalCompact: hidesAmounts ? nil : "$8.2K",
            decimalSeparator: ".",
            change: hidesAmounts ? nil : WidgetChange(text: "+$124.80", isDown: false),
            assets: [
                Asset(id: "gram", symbol: "GRAM", amount: hidesAmounts ? nil : "$4 950.20", icon: UIImage.TKUIKit.Icons.Size44.currencyTon),
                Asset(id: "eth/mainnet/coin", symbol: "ETH", amount: hidesAmounts ? nil : "$2 104.40", icon: nil),
                Asset(id: "btc/mainnet/coin", symbol: "BTC", amount: hidesAmounts ? nil : "$1 191.20", icon: nil),
            ],
            updatedAt: WidgetPreviewData.updatedAt,
            hidesAmounts: hidesAmounts
        )
    }
}

@available(iOS 17.0, *)
#Preview("Small", traits: .fixedLayout(width: 164, height: 164)) {
    BalanceWidgetView(state: .preview(), family: .systemSmall)
        .homeWidgetPreview()
}

@available(iOS 17.0, *)
#Preview("Medium", traits: .fixedLayout(width: 350, height: 164)) {
    BalanceWidgetView(state: .preview(), family: .systemMedium)
        .homeWidgetPreview()
}

@available(iOS 17.0, *)
#Preview("Medium hidden", traits: .fixedLayout(width: 350, height: 164)) {
    BalanceWidgetView(state: .preview(hidesAmounts: true), family: .systemMedium)
        .homeWidgetPreview()
}

@available(iOS 17.0, *)
#Preview("Lock Screen", traits: .fixedLayout(width: 260, height: 90)) {
    HStack(spacing: 12) {
        BalanceWidgetView(state: .preview(), family: .accessoryRectangular)
            .frame(width: 160, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        BalanceWidgetView(state: .preview(), family: .accessoryCircular)
            .frame(width: 72, height: 72)
            .clipShape(Circle())
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .lockWidgetPreview()
}

@available(iOS 17.0, *)
#Preview("No data", traits: .fixedLayout(width: 164, height: 164)) {
    WidgetMessageView(text: TKLocales.Widget.openApp, family: .systemSmall)
        .homeWidgetPreview()
}

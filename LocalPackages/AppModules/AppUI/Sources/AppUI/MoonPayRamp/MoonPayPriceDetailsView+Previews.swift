import SwiftUI
import TKUIKit

extension MoonPayPriceDetailsViewState {
    static let preview = MoonPayPriceDetailsViewState(
        youPay: .init(id: "pay", title: "You pay", value: "$200"),
        rateTitle: "Rate",
        rateText: "1 USD ≈ 1.002 USDT (TON)",
        rateRestartToken: 0,
        rateTimerDuration: 12,
        fees: [
            .init(id: "moonpay", title: "MoonPay fee", value: "$7.90"),
            .init(id: "ecosystem", title: "Ecosystem fee", value: "$5.40"),
        ],
        youGet: .init(id: "get", title: "You get", value: "187.07 USDT (TON)")
    )
}

@available(iOS 17.0, *)
#Preview("Price details", traits: .sizeThatFitsLayout) {
    MoonPayPriceDetailsView(state: .preview, onToggleRateDirection: {})
        .padding(.vertical)
        .background(.backgroundPage)
        .tkPreviewTheme(.deepBlue)
}

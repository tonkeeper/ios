import SwiftUI
import TKUIKit
import WidgetKit

extension TokenListWidgetState {
    static let preview = TokenListWidgetState(
        rows: [
            row("TSLAx", "Tesla", "$393.48", "+5.99%", from: 370, to: 393),
            row("ARB", "Arbitrum", "$0.169", "+2.77%", from: 0.164, to: 0.169),
            row("BNB", "BNB", "$741.68", "+0.54%", from: 736, to: 742),
            row("ETH", "Ethereum", "$2 313.53", "\u{2212}0.76%", from: 2331, to: 2313),
            row("BTC", "Bitcoin", "$79 861.61", "\u{2212}0.54%", from: 80300, to: 79861),
        ],
        period: "24h",
        updatedAt: WidgetPreviewData.updatedAt
    )

    private static func row(_ symbol: String, _ name: String, _ price: String, _ change: String, from: Double, to: Double) -> Row {
        Row(
            id: symbol,
            symbol: symbol,
            name: name,
            icon: nil,
            price: price,
            change: WidgetChange(text: change, isDown: to < from),
            chart: WidgetPreviewData.chart(from: from, to: to, points: 40),
            url: nil
        )
    }
}

@available(iOS 17.0, *)
#Preview("Medium", traits: .fixedLayout(width: 350, height: 164)) {
    TokenListWidgetView(state: .preview, family: .systemMedium)
        .homeWidgetPreview()
}

@available(iOS 17.0, *)
#Preview("Large", traits: .fixedLayout(width: 350, height: 365)) {
    TokenListWidgetView(state: .preview, family: .systemLarge)
        .homeWidgetPreview()
}

@available(iOS 17.0, *)
#Preview("Large, 3 tokens", traits: .fixedLayout(width: 350, height: 365)) {
    TokenListWidgetView(
        state: TokenListWidgetState(rows: Array(TokenListWidgetState.preview.rows.prefix(3)), period: "24h", updatedAt: nil),
        family: .systemLarge
    )
    .homeWidgetPreview()
}

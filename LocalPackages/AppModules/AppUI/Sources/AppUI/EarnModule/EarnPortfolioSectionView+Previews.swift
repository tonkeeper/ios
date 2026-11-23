import SwiftUI
import TKUIKit

@available(iOS 17.0, *)
#Preview("Earn portfolio", traits: .fixedLayout(width: 390, height: 220)) {
    EarnPortfolioSectionView(
        state: .preview,
        onOpenCatalog: {},
        onSelectRow: { _ in },
        onRetry: {},
        onSelectLimit: { _ in }
    )
    .background(.backgroundPage)
    .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("Earn portfolio, over limit", traits: .fixedLayout(width: 390, height: 360)) {
    EarnPortfolioSectionView(
        state: .previewOverLimit,
        onOpenCatalog: {},
        onSelectRow: { _ in },
        onRetry: {},
        onSelectLimit: { _ in }
    )
    .background(.backgroundPage)
    .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("Earn portfolio, stale", traits: .fixedLayout(width: 390, height: 300)) {
    EarnPortfolioSectionView(
        state: .previewStale,
        onOpenCatalog: {},
        onSelectRow: { _ in },
        onRetry: {},
        onSelectLimit: { _ in }
    )
    .background(.backgroundPage)
    .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("Earn portfolio, unavailable", traits: .fixedLayout(width: 390, height: 140)) {
    EarnPortfolioUnavailableSectionView(onRetry: {})
        .background(.backgroundPage)
        .tkPreviewTheme(.deepBlue)
}

private extension EarnPortfolioSectionState {
    static let preview = EarnPortfolioSectionState(
        totalBalance: "$1 230.54",
        isStale: false,
        rows: [
            previewRow(id: "mainnet/0x1", protocolName: "Morpho", price: "$120.54", change: "+$0.50"),
            previewRow(id: "mainnet/0x2", protocolName: "Aave", price: "$1 110", change: "+$20.4"),
        ]
    )

    static let previewOverLimit = EarnPortfolioSectionState(
        totalBalance: preview.totalBalance,
        isStale: false,
        rows: preview.rows + [
            previewRow(id: "mainnet/0x3", protocolName: "Compound", price: "$540.20", change: "+$8.12"),
            previewRow(id: "mainnet/0x4", protocolName: "Euler", price: "$1.03", change: "+$0.03"),
        ]
    )
    .limited(to: .top3)

    static let previewStale = EarnPortfolioSectionState(
        totalBalance: preview.totalBalance,
        isStale: true,
        rows: preview.rows
    )

    static func previewRow(id: String, protocolName: String, price: String, change: String) -> AssetBalanceRowCellContent {
        AssetBalanceRowCellContent(
            id: id,
            title: "USDT",
            badge: "ETHEREUM",
            displayMode: .includingMarketData(
                marketCap: protocolName,
                price: price,
                change: .init(text: change, isPositive: true),
                showsPin: false
            ),
            avatarImageSource: .image(
                .TKUIKit.Icons.Size44.currencyUsdt,
                chainIcon: .TKUIKit.Icons.Size20.ethChain
            )
        )
    }
}

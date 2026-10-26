import SwiftUI
import TKUIKit

@available(iOS 17.0, *)
#Preview("Earn portfolio", traits: .fixedLayout(width: 390, height: 220)) {
    EarnPortfolioSectionView(
        state: .preview,
        onOpenCatalog: {},
        onSelectRow: { _ in },
        onRetry: {}
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
        onRetry: {}
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
            AssetBalanceRowCellContent(
                id: "mainnet/0x1",
                title: "USDT",
                badge: "ETHEREUM",
                displayMode: .includingMarketData(
                    marketCap: "Morpho",
                    price: "$120.54",
                    change: .init(text: "+$0.50", isPositive: true),
                    showsPin: false
                ),
                avatarImageSource: .image(
                    .TKUIKit.Icons.Size44.currencyUsdt,
                    chainIcon: .TKUIKit.Icons.Size20.ethChain
                )
            ),
            AssetBalanceRowCellContent(
                id: "mainnet/0x2",
                title: "USDT",
                badge: "ETHEREUM",
                displayMode: .includingMarketData(
                    marketCap: "Aave",
                    price: "$1 110",
                    change: .init(text: "+$20.4", isPositive: true),
                    showsPin: false
                ),
                avatarImageSource: .image(
                    .TKUIKit.Icons.Size44.currencyUsdt,
                    chainIcon: .TKUIKit.Icons.Size20.ethChain
                )
            ),
        ]
    )

    static let previewStale = EarnPortfolioSectionState(
        totalBalance: preview.totalBalance,
        isStale: true,
        rows: preview.rows
    )
}

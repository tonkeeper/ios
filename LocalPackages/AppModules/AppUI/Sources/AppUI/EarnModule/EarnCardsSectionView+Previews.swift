import SwiftUI
import TKUIKit

@available(iOS 17.0, *)
#Preview("Earn cards", traits: .fixedLayout(width: 390, height: 199)) {
    EarnCardsSectionView(
        cards: .preview,
        onOpenCatalog: {},
        onSelectCard: { _ in }
    )
    .background(.backgroundPage)
    .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("Earn cards, long names", traits: .fixedLayout(width: 390, height: 199)) {
    EarnCardsSectionView(
        cards: .previewLongNames,
        onOpenCatalog: {},
        onSelectCard: { _ in }
    )
    .background(.backgroundPage)
    .tkPreviewTheme(.deepBlue)
}

private extension [EarnCardViewData] {
    static let preview: [EarnCardViewData] = [
        EarnCardViewData(
            network: "base",
            vaultId: "0x1234567890abcdef1234567890abcdef12345678",
            title: "USD₮",
            apy: "3.58% APY",
            protocolName: "Morpho",
            imageSource: .image(
                .TKUIKit.Icons.Size44.currencyUsdt,
                chainIcon: .TKUIKit.Icons.Size20.baseChain
            )
        ),
        EarnCardViewData(
            network: "mainnet",
            vaultId: "0x2234567890abcdef1234567890abcdef12345678",
            title: "ETH",
            apy: "3.41% APY",
            protocolName: "Compound",
            imageSource: .image(
                .TKUIKit.Icons.Size44.ethChain,
                chainIcon: .TKUIKit.Icons.Size20.ethChain
            )
        ),
        EarnCardViewData(
            network: "arbitrum",
            vaultId: "0x3234567890abcdef1234567890abcdef12345678",
            title: "ETH",
            apy: "3.41% APY",
            protocolName: "Compound",
            imageSource: .image(
                .TKUIKit.Icons.Size44.ethChain,
                chainIcon: .TKUIKit.Icons.Size20.arbitrumChain
            )
        ),
        EarnCardViewData(
            network: "bsc",
            vaultId: "0x4234567890abcdef1234567890abcdef12345678",
            title: "GRAM",
            apy: "12.45% APY",
            protocolName: "Aave",
            imageSource: .image(
                .TKUIKit.Icons.Size44.currencyGram,
                chainIcon: .TKUIKit.Icons.Size20.bscChain
            )
        ),
    ]

    static let previewLongNames: [EarnCardViewData] = [
        EarnCardViewData(
            network: "arbitrum",
            vaultId: "0x5234567890abcdef1234567890abcdef12345678",
            title: "WSTETH",
            apy: "128.45% APY",
            protocolName: "Spark Lend",
            imageSource: .image(
                .TKUIKit.Icons.Size44.ethChain,
                chainIcon: .TKUIKit.Icons.Size20.arbitrumChain
            )
        ),
        EarnCardViewData(
            network: "base",
            vaultId: "0x6234567890abcdef1234567890abcdef12345678",
            title: "USD₮",
            apy: "3.58% APY",
            protocolName: "Morpho Blue",
            imageSource: .image(
                .TKUIKit.Icons.Size44.currencyUsdt,
                chainIcon: .TKUIKit.Icons.Size20.baseChain
            )
        ),
    ]
}

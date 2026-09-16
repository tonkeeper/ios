import SwiftUI
import TKLocalize
import TKUIKit

struct TradeAssetDetailsBalanceSectionView: View {
    let balance: TradeAssetDetailsBalanceSectionViewData?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ListTitleView(
                config: balance != nil ? .text(
                    TKLocales.Trade.AssetDetails.Balance.title
                ) : .shimmer()
            )
            AssetBalanceCell(
                config: balance
                    .map { balance in
                        .content(
                            AssetBalanceCellContent(
                                symbol: balance.symbol,
                                chainTag: balance.chainTag,
                                assetImageSource: balance.iconImageSource,
                                amountText: balance.amountText,
                                convertedAmountText: balance.convertedAmountText
                            )
                        )
                    } ?? .shimmer
            )
            .balanceFreshness(balance?.freshness ?? .actual)
            .asCellsGroup(
                config: .init(
                    horizontalPadding: 0
                )
            )
        }
        .padding(.horizontal, Layout.horizontalPadding)
    }
}

private enum Layout {
    static let horizontalPadding: CGFloat = 16
}

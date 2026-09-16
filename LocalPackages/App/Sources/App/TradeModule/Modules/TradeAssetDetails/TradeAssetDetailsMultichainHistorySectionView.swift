import KeeperCore
import SwiftUI
import TKLocalize
import TKUIKit

struct TradeAssetDetailsMultichainHistorySectionView: View {
    let screen: TradeAssetDetailsMultichainHistorySectionViewData
    let onSelectActivity: (MultichainActivity) -> Void
    let onSeeAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ListTitleView(
                config: .text(
                    TKLocales.Trade.AssetDetails.History.title,
                    accessory: ListTitleView.Accessory(
                        title: TKLocales.Trade.AssetDetails.Common.seeAll,
                        action: onSeeAll
                    )
                )
            )
            .padding(.horizontal, Layout.horizontalPadding)

            VStack(spacing: 0) {
                ForEach(Array(screen.items.enumerated()), id: \.element.id) { index, item in
                    MultichainHistoryTransactionCell(
                        item: item,
                        showsDivider: index < screen.items.count - 1
                    ) {
                        onSelectActivity(item.activity)
                    }
                }
            }
            .asCellsGroup(
                config: .init(
                    horizontalPadding: Layout.horizontalPadding
                )
            )
        }
    }
}

private extension TradeAssetDetailsMultichainHistorySectionView {
    enum Layout {
        static let horizontalPadding: CGFloat = 16
    }
}

import SwiftUI
import TKLocalize
import TKUIKit

struct TradeAssetDetailsHistorySectionView: View {
    let screen: TradeAssetDetailsHistorySectionViewData
    let onSelectItem: (String) -> Void
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

            VStack(spacing: 0) {
                ForEach(Array(screen.items.enumerated()), id: \.element.id) { index, item in
                    TKUIKit.TransactionCell(
                        config: .content(
                            .init(
                                icon: item.icon,
                                title: item.title,
                                subtitle: .init(
                                    text: item.subtitle,
                                    style: .primary
                                ),
                                amount: .init(
                                    title: item.amountText,
                                    style: item.amountStyle
                                ),
                                accessory: .init(
                                    text: item.dateText
                                ),
                                showsDivider: index < screen.items.count - 1
                            )
                        ),
                        onTap: {
                            onSelectItem(item.id)
                        }
                    )
                }
            }
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

import Perps
import SwiftUI
import TKLocalize
import TKUIKit

struct TradeAssetDetailsPerpPositionSectionView: View {
    let data: TradeAssetDetailsPerpPositionViewData
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ListTitleView(config: .text(TKLocales.Trade.AssetDetails.PerpPosition.title))
            switch data {
            case .loading:
                AssetBalanceCell(config: .shimmer)
                    .asCellsGroup(config: .init(horizontalPadding: 0))
            case let .banner(_, title, caption):
                bannerView(title: title, caption: caption)
            case let .position(row):
                PerpsOpenPositionsCard(positions: [row], onSelect: { _ in onTap() })
            }
        }
        .padding(.horizontal, Layout.horizontalPadding)
    }
}

private extension TradeAssetDetailsPerpPositionSectionView {
    func bannerView(title: String, caption: String?) -> some View {
        TradePerpsEntryCell(
            title: title,
            caption: caption,
            tags: [.accentTag(text: TKLocales.Common.new, accent: .accentBlue)],
            action: onTap
        )
    }

    enum Layout {
        static let horizontalPadding: CGFloat = 16
    }
}

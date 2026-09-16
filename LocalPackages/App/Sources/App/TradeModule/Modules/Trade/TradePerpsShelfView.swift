import SwiftUI
import TKLocalize
import TKUIKit

struct TradePerpsShelfView: View {
    let markets: [PerpsShelfMarketViewData]
    let onOpenShelf: () -> Void
    let onOpenMarket: (Int64) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ListTitleView(
                config: .text(
                    TKLocales.Trade.PerpsShelf.title,
                    titleAction: onOpenShelf
                )
            )

            ShelfTransitionCardView {
                AssetsGridRowsView(items: markets) { market in
                    TradeMarketCardView(
                        id: market.id,
                        title: market.symbol,
                        imageSource: .url(market.iconURL),
                        changeText: market.changeText,
                        changeColor: market.changeColor,
                        titleTag: .tag(text: market.leverage),
                        height: Layout.itemHeight
                    ) {
                        onOpenMarket(market.id)
                    }
                }
            }
        }
        .padding(.horizontal, Layout.horizontalPadding)
    }
}

private extension TradePerpsShelfView {
    enum Layout {
        static let horizontalPadding: CGFloat = 16
        static let itemHeight: CGFloat = 117
    }
}

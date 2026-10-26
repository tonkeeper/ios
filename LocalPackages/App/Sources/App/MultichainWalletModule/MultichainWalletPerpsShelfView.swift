import SwiftUI
import TKUIKit

struct MultichainWalletPerpsShelfView: View {
    let markets: [PerpsShelfMarketViewData]
    let onOpenMarket: (Int64) -> Void

    var body: some View {
        let scroll = ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Layout.cardSpacing) {
                ForEach(markets) { market in
                    card(for: market)
                }
            }
            .padding(.horizontal, Layout.horizontalPadding)
        }
        .tkImmediateButtonPresses()

        if #available(iOS 16.4, *) {
            scroll.scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        } else {
            scroll
        }
    }

    private func card(for market: PerpsShelfMarketViewData) -> some View {
        Button {
            onOpenMarket(market.id)
        } label: {
            ServiceCardView(
                config: .content(
                    ServiceCardContent(
                        title: market.symbol,
                        imageSource: .url(market.iconURL),
                        changeConfiguration: market.changeText.map {
                            .content(text: $0, color: market.changeColor)
                        },
                        titleTag: .tag(text: market.leverage)
                    )
                ),
                avatarSize: .small,
                height: Layout.cardContentHeight
            )
            .frame(width: Layout.cardWidth)
            .padding(.top, Layout.cardTopPadding)
            .padding(.bottom, Layout.cardBottomPadding)
            .background(
                RoundedRectangle(cornerRadius: Layout.cardCornerRadius, style: .continuous)
                    .fill(.backgroundContent)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(ServiceCardHighlightStyle())
    }
}

private extension MultichainWalletPerpsShelfView {
    enum Layout {
        static let horizontalPadding: CGFloat = 16
        static let cardSpacing: CGFloat = 8
        static let cardWidth: CGFloat = 99.5
        static let cardContentHeight: CGFloat = 105
        static let cardTopPadding: CGFloat = 8
        static let cardBottomPadding: CGFloat = 6
        static let cardCornerRadius: CGFloat = 16
    }
}

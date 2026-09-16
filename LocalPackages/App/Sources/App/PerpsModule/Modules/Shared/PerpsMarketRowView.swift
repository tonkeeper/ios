import SwiftUI
import TKUIKit

struct PerpsMarketRowView: View {
    let market: PerpsMarketRowItem

    var body: some View {
        HStack(spacing: Layout.cardPadding) {
            icon

            VStack(alignment: .leading, spacing: Layout.titleSubtitleSpacing) {
                HStack(spacing: Layout.badgeSpacing) {
                    Text(market.symbol)
                        .textStyle(.label1)
                        .foregroundStyle(.textPrimary)
                    if let leverage = market.leverageText {
                        Text(leverage)
                            .textStyle(.body4)
                            .foregroundStyle(.textSecondary)
                            .padding(.horizontal, Layout.badgeHorizontalPadding)
                            .padding(.vertical, Layout.badgeVerticalPadding)
                            .background(
                                RoundedRectangle(cornerRadius: Layout.badgeCornerRadius)
                                    .fill(.backgroundContentTint)
                            )
                    }
                }
                Text(market.volumeText)
                    .textStyle(.body2)
                    .foregroundStyle(.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: Layout.titleSubtitleSpacing) {
                Text(market.priceText)
                    .textStyle(.label1)
                    .foregroundStyle(.textPrimary)
                Text(market.changeText)
                    .textStyle(.body2)
                    .foregroundStyle(market.isChangePositive ? TKColor.accentGreen : TKColor.accentRed)
            }
        }
        .padding(.horizontal, Layout.cardPadding)
        .padding(.vertical, Layout.rowVerticalPadding)
    }

    @ViewBuilder
    private var icon: some View {
        if let iconURL = market.iconURL {
            AssetAvatarView(imageSource: .url(iconURL), size: .small)
        } else {
            ZStack {
                Circle()
                    .fill(.backgroundContentTint)
                Text(String(market.symbol.prefix(1)))
                    .textStyle(.label2)
                    .foregroundStyle(.textSecondary)
            }
            .frame(width: Layout.iconSide, height: Layout.iconSide)
        }
    }
}

private extension PerpsMarketRowView {
    enum Layout {
        static let cardPadding: CGFloat = 16
        static let titleSubtitleSpacing: CGFloat = -4
        static let iconSide: CGFloat = 44
        static let rowVerticalPadding: CGFloat = 16
        static let badgeSpacing: CGFloat = 4
        static let badgeHorizontalPadding: CGFloat = 4
        static let badgeVerticalPadding: CGFloat = 0
        static let badgeCornerRadius: CGFloat = 4
    }
}

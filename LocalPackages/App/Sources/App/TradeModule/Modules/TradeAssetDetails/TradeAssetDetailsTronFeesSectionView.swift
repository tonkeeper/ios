import SwiftUI
import TKUIKit

struct TradeAssetDetailsTronFeesSectionView: View {
    let data: TradeAssetDetailsTronFeesViewData
    let onTap: () -> Void

    var body: some View {
        switch data {
        case let .banner(banner):
            bannerView(banner)
        case let .transfersAvailable(text):
            transfersAvailableView(text)
        }
    }
}

private extension TradeAssetDetailsTronFeesSectionView {
    func bannerView(_ banner: TradeAssetDetailsTronFeesViewData.Banner) -> some View {
        HStack(alignment: .top, spacing: Layout.contentSpacing) {
            VStack(alignment: .leading, spacing: Layout.textActionSpacing) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(banner.title)
                        .textStyle(.label1)
                        .foregroundStyle(.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(banner.caption)
                        .textStyle(.body2)
                        .foregroundStyle(.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ButtonView(
                    config: ButtonView.Config(
                        title: banner.buttonTitle,
                        size: .small,
                        appearance: .primary,
                        action: onTap
                    )
                )
            }

            bannerIcon(banner.style)
        }
        .padding(.top, Layout.bannerTopPadding)
        .padding(.horizontal, Layout.bannerHorizontalPadding)
        .padding(.bottom, Layout.bannerBottomPadding)
        .background(.backgroundContent)
        .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous))
        .padding(.horizontal, Layout.horizontalPadding)
    }

    @ViewBuilder
    func bannerIcon(_ style: TradeAssetDetailsTronFeesViewData.Banner.Style) -> some View {
        switch style {
        case .battery:
            SwiftUI.Image.TKUIKit.Icons.Size24.flash
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: Layout.batteryIconSize, height: Layout.batteryIconSize)
                .foregroundStyle(.constantWhite)
                .frame(width: Layout.iconSize, height: Layout.iconSize)
                .background(.accentBlue)
                .clipShape(RoundedRectangle(cornerRadius: Layout.batteryIconCornerRadius, style: .continuous))
        case .trx:
            SwiftUI.Image.TKUIKit.Icons.Size44.currencyTrc20
                .resizable()
                .scaledToFit()
                .frame(width: Layout.iconSize, height: Layout.iconSize)
        }
    }

    func transfersAvailableView(_ text: String) -> some View {
        Button(action: onTap) {
            HStack(spacing: Layout.transfersAvailableSpacing) {
                Text(text)
                    .textStyle(.body2)
                SwiftUI.Image.TKUIKit.Icons.Size12.chevronRight
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: Layout.chevronSize, height: Layout.chevronSize)
            }
            .foregroundStyle(.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Layout.horizontalPadding)
    }
}

private extension TradeAssetDetailsTronFeesSectionView {
    enum Layout {
        static let horizontalPadding: CGFloat = 16
        static let cornerRadius: CGFloat = 16
        static let contentSpacing: CGFloat = 16
        static let textActionSpacing: CGFloat = 12
        static let bannerTopPadding: CGFloat = 12
        static let bannerHorizontalPadding: CGFloat = 16
        static let bannerBottomPadding: CGFloat = 16
        static let iconSize: CGFloat = 44
        static let batteryIconSize: CGFloat = 32
        static let batteryIconCornerRadius: CGFloat = 12
        static let transfersAvailableSpacing: CGFloat = 3
        static let chevronSize: CGFloat = 12
    }
}

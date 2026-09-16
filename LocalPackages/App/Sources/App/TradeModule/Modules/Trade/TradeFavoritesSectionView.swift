import SwiftUI
import TKLocalize
import TKUIKit

struct TradeFavoritesSectionView: View {
    let items: [TradeShelfAssetViewData]
    let isEditing: Bool
    let onOpenAsset: (TradeShelfAssetViewData) -> Void
    let onToggleEditing: () -> Void
    let onRemove: (TradeShelfAssetViewData) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, Layout.horizontalPadding)
            cardsScroll
        }
    }

    @ViewBuilder
    private var cardsScroll: some View {
        let scroll = ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Layout.itemSpacing) {
                ForEach(items) { item in
                    cardView(for: item)
                }
            }
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.top, Layout.badgeOverflow)
        }
        .tkImmediateButtonPresses()

        if #available(iOS 16.4, *) {
            scroll.scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        } else {
            scroll
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            Text(isEditing ? TKLocales.Trade.Favorites.editTitle : TKLocales.Trade.Favorites.title)
                .textStyle(.label1)
                .foregroundStyle(.textPrimary)
                .padding(.top, Layout.headerTopPadding)

            Spacer(minLength: 0)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    onToggleEditing()
                }
            } label: {
                if isEditing {
                    Text(TKLocales.Actions.done)
                        .textStyle(.body2)
                        .foregroundStyle(.accentBlue)
                } else {
                    SwiftUI.Image(uiImage: .TKUIKit.Icons.Size16.ellipses)
                        .renderingMode(.template)
                        .foregroundStyle(.iconSecondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.top, Layout.headerTopPadding)
        }
        .frame(height: Layout.headerHeight)
    }

    private func cardView(for item: TradeShelfAssetViewData) -> some View {
        ZStack(alignment: .topTrailing) {
            Button {
                onOpenAsset(item)
            } label: {
                ServiceCardView(
                    config: .content(
                        ServiceCardContent(
                            title: item.symbol,
                            imageSource: item.iconImageSource,
                            changeConfiguration: changeConfiguration(for: item),
                            showsVerificationCheckmark: item.preview.isTrusted == true
                        )
                    ),
                    avatarSize: .small,
                    height: Layout.itemHeight
                )
                .frame(width: Layout.itemWidth)
                .padding(.top, Layout.itemTopPadding)
                .padding(.bottom, Layout.itemBottomPadding)
                .background(
                    RoundedRectangle(cornerRadius: Layout.itemCornerRadius, style: .continuous)
                        .fill(.backgroundContent)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(ServiceCardHighlightStyle())

            removeBadge(for: item)
                .scaleEffect(isEditing ? 1 : 0.1, anchor: .center)
                .opacity(isEditing ? 1 : 0)
                .offset(x: Layout.badgeOverflow, y: -Layout.badgeOverflow)
                .allowsHitTesting(isEditing)
                .animation(.easeInOut(duration: 0.2), value: isEditing)
                .zIndex(1)
        }
    }

    private func removeBadge(for item: TradeShelfAssetViewData) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                onRemove(item)
            }
        } label: {
            ZStack {
                Circle()
                    .fill(.backgroundContentTint)

                SwiftUI.Image(uiImage: .TKUIKit.Icons.Size16.closeSmall)
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: Layout.badgeIconSize, height: Layout.badgeIconSize)
                    .foregroundStyle(.iconSecondary)
            }
            .frame(width: Layout.badgeSize, height: Layout.badgeSize)
        }
        .buttonStyle(.plain)
    }

    func changeConfiguration(for item: TradeShelfAssetViewData) -> ServiceCardCaptionConfig? {
        if item.isChangeLoading {
            return .shimmer
        }

        guard let changeText = item.changeText else {
            return nil
        }

        return .content(
            text: changeText,
            color: item.changeColor
        )
    }
}

private extension TradeFavoritesSectionView {
    enum Layout {
        static let horizontalPadding: CGFloat = 16
        static let itemCornerRadius: CGFloat = 16
        static let itemSpacing: CGFloat = 8
        static let itemHeight: CGFloat = 101
        static let itemWidth: CGFloat = 99.5
        static let itemTopPadding: CGFloat = 8
        static let itemBottomPadding: CGFloat = 6
        static let headerHeight: CGFloat = 48
        static let headerTopPadding: CGFloat = 15
        static let badgeSize: CGFloat = 24
        static let badgeIconSize: CGFloat = 16
        static let badgeOverflow: CGFloat = 4
    }
}

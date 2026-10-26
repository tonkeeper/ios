import SwiftUI
import TKLocalize
import TKUIKit

public struct EarnCardsSectionView: View {
    private let cards: [EarnCardViewData]
    private let onOpenCatalog: () -> Void
    private let onSelectCard: (EarnCardViewData) -> Void

    public init(
        cards: [EarnCardViewData],
        onOpenCatalog: @escaping () -> Void,
        onSelectCard: @escaping (EarnCardViewData) -> Void
    ) {
        self.cards = cards
        self.onOpenCatalog = onOpenCatalog
        self.onSelectCard = onSelectCard
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ListTitleView(
                config: .text(TKLocales.Earn.sectionTitle, titleAction: onOpenCatalog)
            )
            .padding(.horizontal, Layout.horizontalPadding)

            cardsScroll
        }
        .padding(.bottom, Layout.bottomPadding)
    }

    @ViewBuilder
    private var cardsScroll: some View {
        let scroll = ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Layout.cardSpacing) {
                ForEach(cards) { card in
                    Button {
                        onSelectCard(card)
                    } label: {
                        EarnCardView(card: card)
                    }
                    .buttonStyle(TKTapAnimationButtonStyle())
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
}

private extension EarnCardsSectionView {
    enum Layout {
        static let horizontalPadding: CGFloat = 16
        static let cardSpacing: CGFloat = 8
        static let bottomPadding: CGFloat = 16
    }
}

private struct EarnCardView: View {
    let card: EarnCardViewData

    var body: some View {
        VStack(spacing: Layout.contentSpacing) {
            AssetAvatarView(
                imageSource: card.imageSource,
                size: .small
            )

            VStack(spacing: Layout.captionSpacing) {
                VStack(spacing: Layout.titleSpacing) {
                    Text(card.title)
                        .textStyle(.body3)
                        .foregroundStyle(.textPrimary)
                    Text(card.apy)
                        .textStyle(.body3)
                        .foregroundStyle(.accentGreen)
                }

                Text(card.protocolName)
                    .textStyle(.body3)
                    .foregroundStyle(.textSecondary)
            }
            .lineLimit(1)
        }
        .padding(Layout.insets)
        .frame(width: Layout.width)
        .background(
            RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
                .fill(.backgroundContent)
        )
        .contentShape(Rectangle())
    }
}

private extension EarnCardView {
    enum Layout {
        static let width: CGFloat = 99.5
        static let cornerRadius: CGFloat = 16
        static let contentSpacing: CGFloat = 10
        static let captionSpacing: CGFloat = 1
        static let titleSpacing: CGFloat = 2
        static let insets = EdgeInsets(top: 16, leading: 10, bottom: 14, trailing: 10)
    }
}

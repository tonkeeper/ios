import SwiftUI
import TKLocalize
import TKUIKit

public struct PredictionsSectionView: View {
    private let state: PredictionsSectionState
    private let onOpenPredictions: () -> Void
    private let onSelectCard: (PredictionCardViewData) -> Void
    private let onSelectOutcome: (PredictionCardViewData, PredictionOutcome) -> Void

    public init(
        state: PredictionsSectionState,
        onOpenPredictions: @escaping () -> Void,
        onSelectCard: @escaping (PredictionCardViewData) -> Void,
        onSelectOutcome: @escaping (PredictionCardViewData, PredictionOutcome) -> Void
    ) {
        self.state = state
        self.onOpenPredictions = onOpenPredictions
        self.onSelectCard = onSelectCard
        self.onSelectOutcome = onSelectOutcome
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ListTitleView(
                config: .text(
                    TKLocales.Predictions.title,
                    accessory: balanceAccessory,
                    titleAction: onOpenPredictions
                )
            )
            .padding(.horizontal, Layout.horizontalPadding)

            cardsScroll
        }
        .padding(.bottom, Layout.bottomPadding)
    }

    private var balanceAccessory: ListTitleView.Accessory? {
        guard case let .cards(balance?, _) = state else { return nil }
        return ListTitleView.Accessory(
            title: balance,
            icon: .TKUIKit.Icons.Size16.walletOutline,
            foregroundColor: .textSecondary,
            textStyle: .body2,
            action: onOpenPredictions
        )
    }

    @ViewBuilder
    private var cardsScroll: some View {
        let scroll = ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: Layout.cardSpacing) {
                cards
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Layout.horizontalPadding)
        }
        .tkImmediateButtonPresses()

        if #available(iOS 16.4, *) {
            scroll.scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        } else {
            scroll
        }
    }

    @ViewBuilder
    private var cards: some View {
        switch state {
        case .loading:
            ForEach(0 ..< Layout.loadingCardsCount, id: \.self) { _ in
                PredictionLoadingCardView()
            }
        case let .cards(_, cards):
            ForEach(cards) { card in
                Button {
                    onSelectCard(card)
                } label: {
                    PredictionCardView(card: card) { outcome in
                        onSelectOutcome(card, outcome)
                    }
                }
                .buttonStyle(TKTapAnimationButtonStyle())
            }
        }
    }
}

private extension PredictionsSectionView {
    enum Layout {
        static let horizontalPadding: CGFloat = 16
        static let cardSpacing: CGFloat = 8
        static let bottomPadding: CGFloat = 16
        static let loadingCardsCount = 3
    }
}

private struct PredictionCardView: View {
    let card: PredictionCardViewData
    let onSelectOutcome: (PredictionOutcome) -> Void

    @Environment(\.tkPalette) private var palette

    var body: some View {
        PredictionCardContainer {
            HStack(spacing: PredictionCardLayout.headerSpacing) {
                AssetAvatarView(
                    imageSource: card.imageSource,
                    configuration: PredictionCardLayout.avatar
                )

                VStack(alignment: .leading, spacing: 0) {
                    Text(card.title)
                        .textStyle(.label2)
                        .foregroundStyle(.textPrimary)
                        .lineLimit(PredictionCardLayout.titleLineLimit)
                    subtitle
                        .textStyle(.body3)
                        .foregroundStyle(.textSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } footer: {
            switch card.footer {
            case let .outcomes(yes, no):
                HStack(spacing: PredictionCardLayout.buttonsSpacing) {
                    ButtonView(
                        config: ButtonView.Config(
                            title: AttributedString(yes, attributes: AttributeContainer().foregroundColor(palette.accent.green)),
                            size: .small,
                            layoutMode: .fill,
                            appearance: .tertiary,
                            action: { onSelectOutcome(.yes) }
                        )
                    )
                    ButtonView(
                        config: ButtonView.Config(
                            title: no,
                            size: .small,
                            layoutMode: .fill,
                            appearance: .destructive,
                            action: { onSelectOutcome(.no) }
                        )
                    )
                }
            case let .position(position):
                PredictionPositionView(position: position)
            }
        }
    }

    @ViewBuilder
    private var subtitle: some View {
        switch card.subtitle {
        case let .text(text):
            Text(text)
        case let .countdown(text, endsAt):
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text("\(text) · \(Self.countdown(until: endsAt, now: context.date))")
            }
        }
    }

    private static func countdown(until endsAt: Date, now: Date) -> String {
        let seconds = max(0, Int(endsAt.timeIntervalSince(now).rounded(.up)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

private struct PredictionPositionView: View {
    let position: PredictionPositionViewData

    var body: some View {
        HStack(spacing: 0) {
            Text(position.title)
                .foregroundStyle(position.titleColor)
            Text(" · \(position.amount)")
                .foregroundStyle(.textPrimary)
            Spacer(minLength: PredictionCardLayout.positionSpacing)
            Text(position.change)
                .foregroundStyle(position.changeColor)
        }
        .textStyle(.label2)
        .lineLimit(1)
        .padding(.horizontal, PredictionCardLayout.positionHorizontalPadding)
        .frame(height: PredictionCardLayout.footerHeight)
        .background(Capsule(style: .continuous).fill(.buttonTertiaryBackground))
    }
}

private struct PredictionLoadingCardView: View {
    var body: some View {
        PredictionCardContainer {
            HStack(spacing: PredictionCardLayout.headerSpacing) {
                ShimmerSwiftUIView(config: placeholder(.capsule))
                    .frame(width: PredictionCardLayout.avatar.imageSize, height: PredictionCardLayout.avatar.imageSize)

                VStack(alignment: .leading, spacing: PredictionCardLayout.loadingLinesSpacing) {
                    ShimmerSwiftUIView(config: placeholder(.value(PredictionCardLayout.loadingLineCornerRadius)))
                        .frame(width: PredictionCardLayout.loadingTitleWidth, height: PredictionCardLayout.loadingLineHeight)
                    ShimmerSwiftUIView(config: placeholder(.value(PredictionCardLayout.loadingLineCornerRadius)))
                        .frame(width: PredictionCardLayout.loadingSubtitleWidth, height: PredictionCardLayout.loadingLineHeight)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } footer: {
            HStack(spacing: PredictionCardLayout.buttonsSpacing) {
                ShimmerSwiftUIView(config: placeholder(.capsule))
                ShimmerSwiftUIView(config: placeholder(.capsule))
            }
            .frame(height: PredictionCardLayout.footerHeight)
        }
    }

    private func placeholder(_ cornerRadius: ShimmerSwiftUIView.CornerRadius) -> ShimmerSwiftUIView.Config {
        ShimmerSwiftUIView.Config(color: .backgroundContentTint, cornerRadius: cornerRadius)
    }
}

private struct PredictionCardContainer<Header: View, Footer: View>: View {
    @ViewBuilder let header: Header
    @ViewBuilder let footer: Footer

    var body: some View {
        VStack(spacing: PredictionCardLayout.contentSpacing) {
            header
                .frame(maxHeight: .infinity)
            footer
        }
        .padding(PredictionCardLayout.padding)
        .frame(width: PredictionCardLayout.width)
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: PredictionCardLayout.cornerRadius, style: .continuous)
                .fill(.backgroundContent)
        )
        .contentShape(RoundedRectangle(cornerRadius: PredictionCardLayout.cornerRadius, style: .continuous))
    }
}

private enum PredictionCardLayout {
    static let width: CGFloat = 268
    static let padding: CGFloat = 16
    static let cornerRadius: CGFloat = 16
    static let contentSpacing: CGFloat = 12
    static let headerSpacing: CGFloat = 12
    static let titleLineLimit = 2
    static let buttonsSpacing: CGFloat = 8
    static let footerHeight: CGFloat = 36
    static let positionHorizontalPadding: CGFloat = 16
    static let positionSpacing: CGFloat = 8
    static let loadingLinesSpacing: CGFloat = 8
    static let loadingLineHeight: CGFloat = 12
    static let loadingLineCornerRadius: CGFloat = 4
    static let loadingTitleWidth: CGFloat = 160
    static let loadingSubtitleWidth: CGFloat = 100
    static let avatar = AssetAvatarView.Configuration(
        imageSize: 40,
        chainIconSize: 0,
        chainIconPadding: 0,
        chainIconOffsetX: 0,
        chainIconOffsetY: 0
    )
}

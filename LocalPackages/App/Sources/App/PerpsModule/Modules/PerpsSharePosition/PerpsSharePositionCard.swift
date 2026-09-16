import SwiftUI
import TKLocalize
import TKUIKit

struct PerpsSharePositionCard: View {
    static var iconSide: CGFloat {
        Layout.iconSide
    }

    @Environment(\.tkPalette) private var palette
    let model: PerpsSharePositionCardModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            iconCircle

            nameRow
                .padding(.top, Layout.iconToName)

            if let pnlPercentText = model.pnlPercentText {
                Text(pnlPercentText)
                    .font(Font(UIFont.tkMedium(size: Layout.pnlFontSize, features: .display)))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(model.isProfit ? TKColor.accentGreen : TKColor.accentRed)
                    .frame(height: Layout.pnlLineHeight, alignment: .leading)
                    .padding(.top, Layout.nameToPnl)
            }

            stats
                .padding(.top, Layout.pnlToStats)

            SwiftUI.Image(uiImage: .TKUIKit.Artwork.Brand.tonkeeperLogoFull)
                .frame(width: Layout.logoWidth, height: Layout.logoHeight)
                .padding(.top, Layout.statsToLogo)
        }
        .padding(.top, Layout.topInset)
        .padding(.horizontal, Layout.horizontalInset)
        .padding(.bottom, Layout.bottomInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(glow)
        .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius))
    }

    private var glow: some View {
        let glowColor = model.isProfit ? Glow.profit : Glow.loss
        return GeometryReader { proxy in
            palette.background.content
                .overlay(
                    RadialGradient(
                        gradient: Gradient(colors: [glowColor, glowColor.opacity(0)]),
                        center: UnitPoint(x: 0.5, y: 1),
                        startRadius: 0,
                        endRadius: proxy.size.height * Layout.glowRadiusFactor
                    )
                )
        }
    }

    @ViewBuilder
    private var iconCircle: some View {
        if let iconImage = model.iconImage {
            SwiftUI.Image(uiImage: iconImage)
                .resizable()
                .scaledToFill()
                .frame(width: Layout.iconSide, height: Layout.iconSide)
                .clipShape(Circle())
        } else if let iconURL = model.iconURL {
            AssetAvatarView(imageSource: .url(iconURL), size: .regular)
        } else {
            ZStack {
                Circle().fill(.backgroundContentTint)
                Text(model.iconLetter)
                    .textStyle(.h3)
                    .foregroundStyle(.textSecondary)
            }
            .frame(width: Layout.iconSide, height: Layout.iconSide)
        }
    }

    private var nameRow: some View {
        HStack(spacing: 0) {
            Text(model.coinName)
                .textStyle(.h3)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(.textPrimary)
            HStack(spacing: 0) {
                if let leverage = model.leverageText {
                    TKTagSwiftUIView(config: .tag(text: leverage))
                }
                TKTagSwiftUIView(config: .tag(text: model.sideText))
            }
            .padding(.leading, Layout.tagGroupLeading)
        }
    }

    private var stats: some View {
        HStack(alignment: .top, spacing: Layout.statSpacing) {
            stat(label: TKLocales.Perps.Asset.entry, value: model.entryText)
            stat(label: TKLocales.Perps.Asset.current, value: model.currentText)
            stat(label: TKLocales.Perps.Asset.date, value: model.dateText)
        }
    }

    private func stat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: Layout.statLabelToValue) {
            Text(label)
                .textStyle(.body1)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(.textPrimary.opacity(Layout.labelOpacity))
            Text(value)
                .textStyle(.label1)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(.textPrimary)
        }
    }
}

private extension PerpsSharePositionCard {
    enum Glow {
        static let profit = Color(red: 29 / 255, green: 129 / 255, blue: 82 / 255)
        static let loss = Color(red: 154 / 255, green: 38 / 255, blue: 60 / 255)
    }

    enum Layout {
        static let cornerRadius: CGFloat = 16
        static let glowRadiusFactor: CGFloat = 0.85
        static let topInset: CGFloat = 24
        static let horizontalInset: CGFloat = 24
        static let bottomInset: CGFloat = 28
        static let iconSide: CGFloat = 56
        static let iconToName: CGFloat = 10
        static let nameToPnl: CGFloat = 12
        static let pnlToStats: CGFloat = 26
        static let statLabelToValue: CGFloat = -4
        static let statsToLogo: CGFloat = 61
        static let pnlFontSize: CGFloat = 46
        static let pnlLineHeight: CGFloat = 40
        static let statSpacing: CGFloat = 24
        static let labelOpacity: CGFloat = 0.48
        static let tagGroupLeading: CGFloat = 4
        static let logoWidth: CGFloat = 120
        static let logoHeight: CGFloat = 22
    }
}

struct PerpsSharePositionView: View {
    let model: PerpsSharePositionCardModel
    let onShare: () -> Void

    var body: some View {
        VStack(spacing: Layout.spacing) {
            PerpsSharePositionCard(model: model)
            ButtonView(config: .init(
                title: TKLocales.Perps.Asset.share,
                size: .large,
                layoutMode: .fill,
                appearance: .secondary,
                icon: shareIcon,
                action: onShare
            ))
        }
        .padding(.horizontal, Layout.horizontalInset)
        .padding(.bottom, Layout.bottomInset)
    }

    private var shareIcon: ButtonView.Icon {
        ButtonView.Icon(image: .TKUIKit.Icons.Size16.shareArrow, alignment: .leading)
    }
}

private extension PerpsSharePositionView {
    enum Layout {
        static let spacing: CGFloat = 16
        static let horizontalInset: CGFloat = 16
        static let bottomInset: CGFloat = 16
    }
}

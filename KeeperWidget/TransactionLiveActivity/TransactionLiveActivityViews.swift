import SwiftUI
import TKLocalize
import TKUIKit

/// The Lock Screen card keeps the app's Deep Blue look on any wallpaper and appearance, while the
/// Dynamic Island is always black, which is what the Dark palette is drawn for.
///
/// `TKTextStyle` text renders here only because `KeeperWidget/Info.plist` lists the fonts in
/// `UIAppFonts`: TKUIKit registers them in memory, which the out-of-process renderer cannot load,
/// and it then draws no text at all.
@available(iOS 16.2, *)
enum TransactionLiveActivityTheme {
    static let lockScreen = TKResolvedTheme.deepBlue
    static let dynamicIsland = TKResolvedTheme.dark
    /// Added to the system margins of the expanded island, whose large corner radius otherwise crowds
    /// the logo.
    static let expandedInset: CGFloat = 4
}

@available(iOS 16.2, *)
struct TransactionLiveActivityWalletLabel {
    let name: String
    let emoji: String?
    let image: Image?
}

@available(iOS 16.2, *)
struct TransactionLiveActivityLockScreenView: View {
    let presentation: TransactionLiveActivityPresentation
    let wallet: TransactionLiveActivityWalletLabel?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                TransactionLiveActivityLogoView()
                TransactionLiveActivityWalletView(wallet: wallet)
                Spacer(minLength: 2)
                if presentation.showsStaleNotice {
                    TransactionLiveActivityStaleNoticeView()
                        .layoutPriority(1)
                }
            }
            TransactionLiveActivityRowView(presentation: presentation)
        }
        .padding(14)
        .environment(\.tkResolvedTheme, TransactionLiveActivityTheme.lockScreen)
    }
}

@available(iOS 16.2, *)
struct TransactionLiveActivityExpandedLeadingView: View {
    var body: some View {
        TransactionLiveActivityLogoView()
            .frame(maxHeight: .infinity)
            .padding(.leading, TransactionLiveActivityTheme.expandedInset)
            .environment(\.tkResolvedTheme, TransactionLiveActivityTheme.dynamicIsland)
    }
}

/// The wallet goes under the logo rather than beside the camera: on 393-pt iPhones the ~100 pt there
/// does not fit even a regular name like "😀 Main Wallet".
@available(iOS 16.2, *)
struct TransactionLiveActivityExpandedBottomView: View {
    let presentation: TransactionLiveActivityPresentation
    let wallet: TransactionLiveActivityWalletLabel?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TransactionLiveActivityWalletView(wallet: wallet)
            TransactionLiveActivityRowView(presentation: presentation)
            if presentation.showsStaleNotice {
                TransactionLiveActivityStaleNoticeView()
            }
        }
        .padding(.horizontal, TransactionLiveActivityTheme.expandedInset)
        .environment(\.tkResolvedTheme, TransactionLiveActivityTheme.dynamicIsland)
    }
}

@available(iOS 16.2, *)
struct TransactionLiveActivityCompactLeadingView: View {
    let presentation: TransactionLiveActivityPresentation

    var body: some View {
        TransactionLiveActivityGlyphView(presentation: presentation, size: .compact)
            .environment(\.tkResolvedTheme, TransactionLiveActivityTheme.dynamicIsland)
    }
}

@available(iOS 16.2, *)
struct TransactionLiveActivityCompactTrailingView: View {
    /// The trailing compact region of the smallest Dynamic Island (52.33 pt on 393-pt iPhones) less the
    /// system inset. Anything wider stretches the island over the status bar.
    private static let width: CGFloat = 46

    let presentation: TransactionLiveActivityPresentation

    var body: some View {
        ViewThatFits(in: .horizontal) {
            ForEach(presentation.compactValues, id: \.self) { value in
                Text(value)
                    .textStyle(.label2)
                    .foregroundStyle(presentation.tone.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(maxWidth: Self.width, alignment: .leading)
        .environment(\.tkResolvedTheme, TransactionLiveActivityTheme.dynamicIsland)
    }
}

@available(iOS 16.2, *)
private struct TransactionLiveActivityGlyphView: View {
    enum Size {
        case regular
        case compact

        var side: CGFloat {
            switch self {
            case .regular: 44
            case .compact: 24
            }
        }

        func icon(isRinged: Bool) -> CGFloat {
            switch self {
            case .regular: isRinged ? 24 : 28
            case .compact: isRinged ? 12 : 16
            }
        }

        var ring: CGFloat {
            switch self {
            case .regular: 3
            case .compact: 2.5
            }
        }

        /// A tinted disc vanishes on the black island at compact size, so it gets a solid one.
        var isFilled: Bool {
            self == .compact
        }
    }

    let presentation: TransactionLiveActivityPresentation
    let size: Size

    var body: some View {
        let isRinged = presentation.progress != nil
        // On the island the ring stands out on its own, around a glyph tinted like it.
        let isFilled = size.isFilled && !isRinged
        let iconSide = size.icon(isRinged: isRinged)
        ZStack {
            Circle()
                .fill(presentation.tone.color)
                .opacity(isFilled ? 1 : 0.16)
            if let progress = presentation.progress {
                Circle()
                    .inset(by: size.ring / 2)
                    .trim(from: 0, to: progress)
                    .stroke(presentation.tone.color, style: StrokeStyle(lineWidth: size.ring, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            presentation.glyph.image
                .resizable()
                .renderingMode(.template)
                .foregroundStyle(isFilled ? .constantWhite : presentation.tone.color)
                .frame(width: iconSide, height: iconSide)
        }
        .frame(width: size.side, height: size.side)
        .accessibilityHidden(true)
    }
}

@available(iOS 16.2, *)
private struct TransactionLiveActivityLogoView: View {
    var body: some View {
        Image.TKUIKit.Icons.Size20.tonkeeperSmall
            .resizable()
            .renderingMode(.template)
            .foregroundStyle(.accentBlue)
            .frame(width: 16, height: 16)
            .accessibilityHidden(true)
    }
}

@available(iOS 16.2, *)
private struct TransactionLiveActivityRowView: View {
    let presentation: TransactionLiveActivityPresentation

    var body: some View {
        HStack(spacing: 12) {
            TransactionLiveActivityGlyphView(presentation: presentation, size: .regular)
            TransactionLiveActivityTitleView(presentation: presentation)
            TransactionLiveActivityAmountView(presentation: presentation)
        }
        .accessibilityElement(children: .combine)
    }
}

@available(iOS 16.2, *)
private struct TransactionLiveActivityTitleView: View {
    let presentation: TransactionLiveActivityPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The amounts never shrink, so a long stage name next to a large amount wraps instead.
            Text(presentation.title)
                .textStyle(.label1)
                .foregroundStyle(.textPrimary)
                .lineLimit(2)
            if let subtitle = presentation.subtitle {
                Text(subtitle)
                    .textStyle(.body2)
                    .foregroundStyle(.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@available(iOS 16.2, *)
private struct TransactionLiveActivityAmountView: View {
    let presentation: TransactionLiveActivityPresentation

    var body: some View {
        if presentation.amount != nil || presentation.secondaryAmount != nil {
            VStack(alignment: .trailing, spacing: 0) {
                if let amount = presentation.amount {
                    Text(amount.text)
                        .textStyle(.label1)
                        .foregroundStyle(amount.style.color)
                }
                if let secondaryAmount = presentation.secondaryAmount {
                    Text(secondaryAmount.text)
                        .textStyle(.body2)
                        .foregroundStyle(secondaryAmount.style.color)
                }
            }
            .lineLimit(1)
            .fixedSize()
        }
    }
}

@available(iOS 16.2, *)
private struct TransactionLiveActivityWalletView: View {
    let wallet: TransactionLiveActivityWalletLabel?

    var body: some View {
        HStack(spacing: 4) {
            if let emoji = wallet?.emoji {
                Text(emoji)
                    .font(.system(size: 12))
            } else if let image = wallet?.image {
                image
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(.iconSecondary)
                    .frame(width: 14, height: 14)
            }
            Text(wallet?.name ?? "Tonkeeper")
                .textStyle(.label2)
                .foregroundStyle(.textSecondary)
                .lineLimit(1)
        }
    }
}

@available(iOS 16.2, *)
private struct TransactionLiveActivityStaleNoticeView: View {
    var body: some View {
        Text(TKLocales.LiveActivity.statusMayHaveChanged)
            .textStyle(.body3)
            .foregroundStyle(.accentOrange)
            .lineLimit(1)
    }
}

@available(iOS 16.2, *)
extension TransactionLiveActivityPresentation.Tone {
    var color: TKColor {
        switch self {
        case .pending: .accentBlue
        case .success: .accentGreen
        case .failure: .accentRed
        case .neutral: .iconSecondary
        }
    }
}

@available(iOS 16.2, *)
private extension TransactionLiveActivityPresentation.Amount.Style {
    var color: TKColor {
        switch self {
        case .primary: .textPrimary
        case .positive: .accentGreen
        case .secondary: .textSecondary
        }
    }
}

@available(iOS 16.2, *)
private extension TransactionLiveActivityPresentation.Glyph {
    var image: Image {
        switch self {
        case .send: Image.TKUIKit.Icons.Size28.trayArrowUp
        case .receive: Image.TKUIKit.Icons.Size28.trayArrowDown
        case .swap: Image.TKUIKit.Icons.Size28.swapHorizontalAlternative
        case .perps: Image.TKUIKit.Icons.Size28.perps
        case .pending: Image.TKUIKit.Icons.Size28.clock
        case .confirmed: Image.TKUIKit.Icons.Size28.donemark
        case .failed: Image.TKUIKit.Icons.Size28.xmark
        case .unknown: Image.TKUIKit.Icons.Size28.question
        }
    }
}

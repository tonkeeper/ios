import SwiftUI
import TKLocalize
import TKUIKit
import UIKit

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
    /// the header.
    static let expandedInset: CGFloat = 6
}

/// Where the activity is drawn: the badge ring and the progress track blend into its background.
@available(iOS 16.2, *)
enum TransactionLiveActivitySurface {
    case lockScreen
    case dynamicIsland

    var background: TKColor {
        switch self {
        case .lockScreen: .backgroundPage
        case .dynamicIsland: .constantBlack
        }
    }

    var track: TKColor {
        switch self {
        case .lockScreen: .backgroundContentTint
        case .dynamicIsland: Self.islandTrack
        }
    }

    static let islandTrack = TKColor.constantWhite.opacity(0.16)
}

@available(iOS 16.2, *)
struct TransactionLiveActivityLockScreenView: View {
    let presentation: TransactionLiveActivityPresentation
    let walletName: String?

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                TransactionLiveActivityWalletView(name: walletName, queuedCount: presentation.queuedCount)
                Spacer(minLength: 0)
                TransactionLiveActivityStatusView(presentation: presentation)
            }
            TransactionLiveActivityRowView(presentation: presentation, surface: .lockScreen)
            TransactionLiveActivityProgressBar(progress: presentation.progress, surface: .lockScreen)
        }
        .padding(20)
        .environment(\.tkResolvedTheme, TransactionLiveActivityTheme.lockScreen)
    }
}

/// The header sits beside the camera; the wallet name gives way to the status first.
@available(iOS 16.2, *)
struct TransactionLiveActivityExpandedLeadingView: View {
    let presentation: TransactionLiveActivityPresentation
    let walletName: String?

    var body: some View {
        TransactionLiveActivityWalletView(name: walletName, queuedCount: presentation.queuedCount)
            .padding(.leading, TransactionLiveActivityTheme.expandedInset)
            .environment(\.tkResolvedTheme, TransactionLiveActivityTheme.dynamicIsland)
    }
}

@available(iOS 16.2, *)
struct TransactionLiveActivityExpandedTrailingView: View {
    let presentation: TransactionLiveActivityPresentation

    var body: some View {
        TransactionLiveActivityStatusView(presentation: presentation)
            .padding(.trailing, TransactionLiveActivityTheme.expandedInset)
            .environment(\.tkResolvedTheme, TransactionLiveActivityTheme.dynamicIsland)
    }
}

@available(iOS 16.2, *)
struct TransactionLiveActivityExpandedBottomView: View {
    let presentation: TransactionLiveActivityPresentation

    var body: some View {
        VStack(spacing: 14) {
            TransactionLiveActivityRowView(presentation: presentation, surface: .dynamicIsland)
            TransactionLiveActivityProgressBar(progress: presentation.progress, surface: .dynamicIsland)
        }
        .padding(.top, 8)
        .environment(\.tkResolvedTheme, TransactionLiveActivityTheme.dynamicIsland)
    }
}

/// Also the minimal presentation, which has room for nothing else.
@available(iOS 16.2, *)
struct TransactionLiveActivityCompactLeadingView: View {
    let presentation: TransactionLiveActivityPresentation

    var body: some View {
        ZStack {
            TransactionLiveActivityProgressRing(progress: presentation.progress)
            TransactionLiveActivityTokenView(presentation: presentation, side: 18)
        }
        .frame(width: 28, height: 28)
        .environment(\.tkResolvedTheme, TransactionLiveActivityTheme.dynamicIsland)
    }
}

@available(iOS 16.2, *)
struct TransactionLiveActivityCompactTrailingView: View {
    /// The amount's width in the design's widest compact island. A longer amount falls back to a shorter
    /// value instead of stretching the island over the status bar.
    private static let maxWidth: CGFloat = 84

    let presentation: TransactionLiveActivityPresentation

    var body: some View {
        ViewThatFits(in: .horizontal) {
            ForEach(presentation.compactValues, id: \.self) { value in
                Text(value)
                    .textStyle(.label2)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: Self.maxWidth, alignment: .trailing)
        .foregroundStyle((presentation.amount?.style ?? .primary).color)
        .environment(\.tkResolvedTheme, TransactionLiveActivityTheme.dynamicIsland)
    }
}

@available(iOS 16.2, *)
private struct TransactionLiveActivityWalletView: View {
    let name: String?
    let queuedCount: Int

    var body: some View {
        HStack(spacing: 6) {
            Image.TKUIKit.Icons.Size16.keeper
                .resizable()
                .frame(width: 16, height: 16)
                .accessibilityHidden(true)
            if let name {
                Text(name)
                    .textStyle(.label3)
                    .foregroundStyle(.textSecondary)
                    .lineLimit(1)
            }
            if queuedCount > 0 {
                Text(TKLocales.LiveActivity.more(queuedCount))
                    .textStyle(.label3)
                    .foregroundStyle(.textSecondary)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(.backgroundContentTint))
                    .fixedSize()
            }
        }
    }
}

@available(iOS 16.2, *)
private struct TransactionLiveActivityStatusView: View {
    let presentation: TransactionLiveActivityPresentation

    var body: some View {
        Text(presentation.status)
            .textStyle(.label3)
            .foregroundStyle(presentation.statusTone.textColor)
            .lineLimit(1)
            .layoutPriority(1)
    }
}

@available(iOS 16.2, *)
private struct TransactionLiveActivityRowView: View {
    let presentation: TransactionLiveActivityPresentation
    let surface: TransactionLiveActivitySurface

    var body: some View {
        HStack(spacing: 12) {
            TransactionLiveActivityTokenView(presentation: presentation, side: 44)
                .overlay(alignment: .bottomTrailing) {
                    TransactionLiveActivityBadgeView(presentation: presentation, surface: surface)
                        .offset(x: 2, y: 2)
                }
            VStack(alignment: .leading, spacing: 0) {
                Text(presentation.title)
                    .textStyle(.label1)
                    .foregroundStyle(.textPrimary)
                if let subtitle = presentation.subtitle {
                    Text(subtitle)
                        .textStyle(.body2)
                        .foregroundStyle(.textSecondary)
                }
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            TransactionLiveActivityAmountView(presentation: presentation)
        }
        .frame(height: 44)
        .accessibilityElement(children: .combine)
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

/// The token logo the app saved, or the operation's glyph on a tinted disc while there is none.
@available(iOS 16.2, *)
private struct TransactionLiveActivityTokenView: View {
    let presentation: TransactionLiveActivityPresentation
    let side: CGFloat

    var body: some View {
        Group {
            if let image = presentation.icon
                .flatMap(TransactionLiveActivityIcons.url(named:))
                .flatMap({ UIImage(contentsOfFile: $0.path) })
            {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(.constantBlack.opacity(0.06), lineWidth: side / 100))
            } else {
                ZStack {
                    Circle()
                        .fill(presentation.badgeTone.fillColor)
                        .opacity(0.16)
                    presentation.glyph.image
                        .resizable()
                        .renderingMode(.template)
                        .foregroundStyle(presentation.badgeTone.fillColor)
                        .frame(width: side * 0.6, height: side * 0.6)
                }
            }
        }
        .frame(width: side, height: side)
        .accessibilityHidden(true)
    }
}

@available(iOS 16.2, *)
private struct TransactionLiveActivityBadgeView: View {
    let presentation: TransactionLiveActivityPresentation
    let surface: TransactionLiveActivitySurface

    var body: some View {
        ZStack {
            Circle()
                .fill(surface.background)
                .frame(width: 24, height: 24)
            Circle()
                .fill(presentation.badgeTone.fillColor)
                .frame(width: 20, height: 20)
            presentation.badge.image
                .resizable()
                .renderingMode(.template)
                .foregroundStyle(.constantWhite)
                .frame(width: 12, height: 12)
        }
        .frame(width: 20, height: 20)
        .accessibilityHidden(true)
    }
}

@available(iOS 16.2, *)
private struct TransactionLiveActivityProgressBar: View {
    let progress: TransactionLiveActivityPresentation.Progress
    let surface: TransactionLiveActivitySurface

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0 ..< progress.steps, id: \.self) { step in
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(surface.track)
                        Capsule()
                            .fill(progress.tone.fillColor)
                            .frame(width: proxy.size.width * progress.fill(of: step))
                    }
                }
            }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }
}

/// The bar bent around the logo: one arc per step, with a gap between steps and at the top.
@available(iOS 16.2, *)
private struct TransactionLiveActivityProgressRing: View {
    private static let lineWidth: CGFloat = 2.5
    private static let gap: Double = 24

    let progress: TransactionLiveActivityPresentation.Progress

    var body: some View {
        let span = 360 / Double(progress.steps)
        let style = StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round)
        ZStack {
            ForEach(0 ..< progress.steps, id: \.self) { step in
                let start = (Double(step) * span + Self.gap / 2) / 360
                let length = (span - Self.gap) / 360
                Circle()
                    .inset(by: Self.lineWidth / 2)
                    .trim(from: start, to: start + length)
                    .stroke(TransactionLiveActivitySurface.islandTrack, style: style)
                let fill = progress.fill(of: step)
                if fill > 0 {
                    Circle()
                        .inset(by: Self.lineWidth / 2)
                        .trim(from: start, to: start + length * fill)
                        .stroke(progress.tone.fillColor, style: style)
                }
            }
        }
        .rotationEffect(.degrees(-90))
        .accessibilityHidden(true)
    }
}

@available(iOS 16.2, *)
extension TransactionLiveActivityPresentation.Progress {
    /// How much of `step`, from 0, is filled: from 0 to 1.
    func fill(of step: Int) -> Double {
        min(max(filled - Double(step), 0), 1)
    }
}

@available(iOS 16.2, *)
extension TransactionLiveActivityPresentation.Tone {
    var fillColor: TKColor {
        switch self {
        case .pending: .accentBlue
        case .success: .accentGreen
        case .failure: .accentRed
        case .warning: .accentOrange
        case .neutral: .textTertiary
        }
    }

    var textColor: TKColor {
        switch self {
        case .pending, .neutral: .textSecondary
        case .success: .accentGreen
        case .failure: .accentRed
        case .warning: .accentOrange
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
        }
    }
}

@available(iOS 16.2, *)
private extension TransactionLiveActivityPresentation.Badge {
    var image: Image {
        switch self {
        case .arrowUp: Image.TKUIKit.Icons.Size16.arrowUp
        case .arrowDown: Image.TKUIKit.Icons.Size16.arrowDown
        case .swap: Image.TKUIKit.Icons.Size16.swapVertical
        case .trayArrowDown: Image.TKUIKit.Icons.Size16.trayArrowDown
        case .trayArrowUp: Image.TKUIKit.Icons.Size16.trayArrowUp
        case .clock: Image.TKUIKit.Icons.Size16.clock
        case .done: Image.TKUIKit.Icons.Size16.doneBold
        case .cross: Image.TKUIKit.Icons.Size16.closeBold
        case .question: Image.TKUIKit.Icons.Size16.question
        }
    }
}

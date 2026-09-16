import SwiftUI
import TKUIKit

/// Scrolls `text` sideways under a gradient fade, the way the TonConnect connect header tickers its
/// wallet address. Two copies run back to back and the offset wraps over one copy's width, so the loop
/// has no seam; the pace is a fixed points-per-second so it does not depend on how long the text is.
struct WalletConnectProposalTickerText: View {
    enum Fade {
        case leading
        case trailing
    }

    let text: String
    let fade: Fade
    let width: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var textWidth: CGFloat = 0
    @State private var startDate = Date()

    var body: some View {
        Group {
            if scrolls {
                TimelineView(.animation) { context in
                    strip
                        .offset(x: offset(at: context.date))
                }
            } else {
                // Sized to the text, not to the window: letting the frame squeeze it would truncate the
                // address with an ellipsis, and the clip plus gradient already hide the overflow.
                textView
                    .fixedSize()
                    .frame(width: width, alignment: fade.restingAlignment)
            }
        }
        .frame(width: width, alignment: .leading)
        .clipped()
        .mask(fade.gradient)
        .background(widthReader)
        .onPreferenceChange(TickerTextWidthKey.self) { textWidth = $0 }
    }
}

private extension WalletConnectProposalTickerText {
    /// Text that already fits the window would show its own repeat next to it rather than read as a
    /// ticker, so it stays put. The TonConnect header cannot reach that case: it scrolls a full address
    /// through half its width.
    var scrolls: Bool {
        !reduceMotion && textWidth > width
    }

    var strip: some View {
        HStack(spacing: 0) {
            textView
                .fixedSize()
            textView
                .fixedSize()
        }
    }

    /// Measured outside the timeline so the text is sized once, not on every animation frame.
    var widthReader: some View {
        textView
            .fixedSize()
            .hidden()
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(
                            key: TickerTextWidthKey.self,
                            value: proxy.size.width
                        )
                }
            )
    }

    var textView: some View {
        Text(text)
            .textStyle(.body2)
            .foregroundStyle(.textTertiary)
            .lineLimit(1)
    }

    func offset(at date: Date) -> CGFloat {
        guard textWidth > 0 else { return 0 }
        let travelled = date.timeIntervalSince(startDate) * Layout.pointsPerSecond
        let phase = travelled.truncatingRemainder(dividingBy: Double(textWidth))
        return CGFloat(phase) - textWidth
    }

    enum Layout {
        static let pointsPerSecond: Double = 25
    }
}

private struct TickerTextWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private extension WalletConnectProposalTickerText.Fade {
    var gradient: LinearGradient {
        switch self {
        case .leading:
            return LinearGradient(
                colors: [.clear, .black],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .trailing:
            return LinearGradient(
                colors: [.black, .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    /// Where the text sits when it is not scrolling, so a reduced-motion render keeps the readable end
    /// against the separator.
    var restingAlignment: Alignment {
        switch self {
        case .leading:
            return .trailing
        case .trailing:
            return .leading
        }
    }
}

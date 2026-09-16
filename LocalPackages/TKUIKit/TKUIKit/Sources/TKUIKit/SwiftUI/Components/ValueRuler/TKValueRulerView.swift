import SwiftUI
import UIKit

/// Horizontal ruler picker: numbered ticks under a fixed center indicator. The strip offset is
/// derived directly from `value` (tick `value` is always centered under the indicator), so the
/// marks and the value can't drift and no snapping is needed. Dragging steps the value by whole
/// ticks relative to where the drag began.
///
/// Values are whole integers only. Every value in `range` is rendered as its own tick (no
/// windowing), so this is intended for bounded ranges on the order of tens — not thousands.
public struct TKValueRulerView: View {
    @Environment(\.tkPalette) private var palette

    public struct Configuration {
        public var tickSpacing: CGFloat
        public var tickWidth: CGFloat
        public var tickHeight: CGFloat
        public var indicatorWidth: CGFloat
        public var height: CGFloat
        public var tickColor: TKColor
        public var indicatorColor: TKColor
        public var labelColor: TKColor
        public var labelTextStyle: TKTextStyle

        public init(
            tickSpacing: CGFloat = 26,
            tickWidth: CGFloat = 1.5,
            tickHeight: CGFloat = 32,
            indicatorWidth: CGFloat = 3,
            height: CGFloat = 64,
            tickColor: TKColor = .iconTertiary,
            indicatorColor: TKColor = .accentBlue,
            labelColor: TKColor = .textSecondary,
            labelTextStyle: TKTextStyle = .body4Caps
        ) {
            self.tickSpacing = tickSpacing
            self.tickWidth = tickWidth
            self.tickHeight = tickHeight
            self.indicatorWidth = indicatorWidth
            self.height = height
            self.tickColor = tickColor
            self.indicatorColor = indicatorColor
            self.labelColor = labelColor
            self.labelTextStyle = labelTextStyle
        }
    }

    private let range: ClosedRange<Int>
    @Binding private var value: Int
    private let configuration: Configuration

    /// Value at the moment the drag began; drag translation is measured against it.
    @State private var dragStartValue: Int?

    public init(range: ClosedRange<Int>, value: Binding<Int>, configuration: Configuration = .init()) {
        self.range = range
        _value = value
        self.configuration = configuration
    }

    /// The displayed value pinned into `range`; guards against a caller passing an out-of-range value.
    private var clampedValue: Int {
        min(max(value, range.lowerBound), range.upperBound)
    }

    public var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let stripOffset = width / 2 - configuration.tickSpacing / 2
                - CGFloat(clampedValue - range.lowerBound) * configuration.tickSpacing
            // Anchor the strip's leading at x=0 (overlay over a fixed-width base) so the offset
            // math centers `value`; a ZStack would size to the wider strip and re-center it.
            Color.clear
                .frame(width: width, height: configuration.height)
                .overlay(alignment: .leading) {
                    ticks
                        .offset(x: stripOffset)
                        .animation(.easeOut(duration: 0.12), value: clampedValue)
                }
                .overlay(indicator)
                .mask(fadeMask)
                .contentShape(Rectangle())
                .gesture(drag)
        }
        .frame(height: configuration.height)
        .accessibilityElement(children: .ignore)
        .accessibilityValue(Text("\(clampedValue)"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                value = min(clampedValue + 1, range.upperBound)
            case .decrement:
                value = max(clampedValue - 1, range.lowerBound)
            @unknown default:
                break
            }
        }
    }

    private var ticks: some View {
        HStack(spacing: 0) {
            ForEach(Array(range), id: \.self) { tickValue in
                VStack(spacing: 2) {
                    Text("\(tickValue)")
                        .font(Font(configuration.labelTextStyle.font))
                        .foregroundColor(configuration.labelColor.resolve(palette))
                    RoundedRectangle(cornerRadius: 100)
                        .fill(configuration.tickColor)
                        .frame(width: configuration.tickWidth, height: configuration.tickHeight)
                }
                .frame(width: configuration.tickSpacing, height: configuration.height, alignment: .bottom)
                // The centered tick is replaced by the indicator.
                .opacity(tickValue == clampedValue ? 0 : 1)
            }
        }
    }

    private var indicator: some View {
        RoundedRectangle(cornerRadius: 100)
            .fill(configuration.indicatorColor)
            .frame(width: configuration.indicatorWidth, height: configuration.height)
    }

    private var fadeMask: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.22),
                .init(color: .black, location: 0.78),
                .init(color: .clear, location: 1),
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                let start = dragStartValue ?? value
                if dragStartValue == nil { dragStartValue = start }
                // Dragging right reveals lower values at the center.
                let steps = Int((gesture.translation.width / configuration.tickSpacing).rounded())
                let target = min(max(start - steps, range.lowerBound), range.upperBound)
                if target != value { value = target }
            }
            .onEnded { _ in dragStartValue = nil }
    }
}

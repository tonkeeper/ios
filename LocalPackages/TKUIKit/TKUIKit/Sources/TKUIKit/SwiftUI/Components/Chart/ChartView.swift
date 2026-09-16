import SwiftUI
import UIKit

public struct ChartView: View {
    private let config: Config
    private let scenario: Scenario

    @StateObject private var interactionState: TKLineChartInteractionState

    public init(
        config: Config,
        scenario: Scenario = .nonInteractive
    ) {
        self.config = config
        self.scenario = scenario
        self._interactionState = StateObject(
            wrappedValue: TKLineChartInteractionState(chartData: config.model.chartData)
        )
    }

    public var body: some View {
        VStack(spacing: 0) {
            ModernChartHeaderView(configuration: config.header)

            ChartTopPriceView(
                config: ChartTopPriceView.Config(
                    textStyle: Layout.priceTextStyle,
                    priceText: config.model.topPrice
                )
            )

            ZStack(alignment: .topLeading) {
                ChartSubstrateGuides(
                    renderer: interactionState.renderer,
                    style: config.model.bottom.substrate.style,
                    chartHeight: Layout.chartHeight
                )
                .frame(height: ChartVerticalGuideLayout.chartAndBottomHeight)

                VStack(spacing: 0) {
                    ChartCanvas(
                        chartData: config.model.chartData,
                        scenario: scenario,
                        interactionState: interactionState
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: Layout.chartHeight)

                    ChartBottomPriceView(
                        config: ChartBottomPriceView.Config(
                            textStyle: Layout.priceTextStyle,
                            priceText: config.model.bottom.bottomPrice,
                            leadingDate: config.model.bottom.substrate.leftValue,
                            middleDate: config.model.bottom.substrate.middleValue
                        )
                    )
                }

                ChartSelectionGuides(
                    renderer: interactionState.renderer,
                    chartHeight: Layout.chartHeight
                )
                .frame(height: ChartVerticalGuideLayout.chartAndBottomHeight)
            }
            .frame(height: ChartVerticalGuideLayout.chartAndBottomHeight)
            .modifier(SkeletonPulseModifier(isEnabled: config.model.chartData.style == .skeleton))

            if let config = config.model.buttons {
                ChartBottomButtonsView(config: config)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

public extension ChartView {
    typealias Scenario = TKLineChartCanvasView.Scenario

    static func height(showsBottomButtons: Bool) -> CGFloat {
        [
            ModernChartHeaderView.Layout.height,
            ChartTopPriceView.Layout.height,
            Layout.chartHeight,
            ChartBottomPriceView.Layout.height,
            showsBottomButtons ? ChartBottomButtonsView.Layout.height : 0,
        ].reduce(0, +)
    }

    struct Substrate {
        public var leftValue: String
        public var middleValue: String
        public var style: TKLineChartCanvasView.VisualStyle

        public init(
            leftValue: String,
            middleValue: String,
            style: TKLineChartCanvasView.VisualStyle
        ) {
            self.leftValue = leftValue
            self.middleValue = middleValue
            self.style = style
        }
    }

    struct Bottom {
        public var bottomPrice: String
        public var substrate: Substrate

        public init(
            bottomPrice: String,
            substrate: Substrate
        ) {
            self.bottomPrice = bottomPrice
            self.substrate = substrate
        }
    }

    struct Model {
        public var chartData: TKLineChartCanvasView.ChartData
        public var topPrice: String
        public var bottom: Bottom
        public var buttons: ChartBottomButtonsView.Config?

        public init(
            chartData: TKLineChartCanvasView.ChartData,
            topPrice: String,
            bottom: Bottom,
            buttons: ChartBottomButtonsView.Config?
        ) {
            self.chartData = chartData
            self.topPrice = topPrice
            self.bottom = bottom
            self.buttons = buttons
        }
    }

    struct Config {
        public var header: ModernChartHeaderView.Configuration
        public var model: Model

        public init(
            header: ModernChartHeaderView.Configuration,
            model: Model
        ) {
            self.header = header
            self.model = model
        }

        public init(
            header: ModernChartHeaderView.Configuration,
            chartData: TKLineChartCanvasView.ChartData,
            topPrice: String,
            bottom: Bottom,
            buttons: ChartBottomButtonsView.Config?
        ) {
            self.init(
                header: header,
                model: Model(
                    chartData: chartData,
                    topPrice: topPrice,
                    bottom: bottom,
                    buttons: buttons
                )
            )
        }
    }
}

extension ChartView {
    enum Layout {
        static let chartHeight: CGFloat = 176

        static let priceTextStyle = TKTextStyle(
            font: .monospacedSystemFont(
                ofSize: 12,
                weight: .medium
            ),
            lineHeight: 16
        )
    }
}

private struct ChartCanvas: View {
    let chartData: TKLineChartCanvasView.ChartData
    let scenario: TKLineChartCanvasView.Scenario
    let interactionState: TKLineChartInteractionState

    var body: some View {
        TKLineChartCanvasView(
            chartData: chartData,
            scenario: scenario,
            selectionGuideHeight: nil,
            interactionState: interactionState,
            showsSelectionIndicator: false
        )
    }
}

private struct ChartSubstrateGuides: View {
    @Environment(\.tkPalette) private var palette

    @ObservedObject var renderer: TKLineChartRenderer
    let style: TKLineChartCanvasView.VisualStyle
    let chartHeight: CGFloat

    var body: some View {
        let renderModel = renderer.renderModel
        ChartSubstrateGridView(
            style: style,
            color: renderModel.substrateGridLineColor(palette)
        )
        .mask {
            ChartExtendedAreaMaskView(
                yValues: renderModel.animatedYValues,
                mode: renderModel.mode,
                smoothing: renderModel.smoothing,
                chartHeight: chartHeight
            )
        }
        .allowsHitTesting(false)
    }
}

private struct ChartSelectionGuides: View {
    @ObservedObject var renderer: TKLineChartRenderer
    let chartHeight: CGFloat

    var body: some View {
        GeometryReader { proxy in
            ChartSelectionIndicatorView(
                renderer: renderer,
                chartSize: CGSize(
                    width: proxy.size.width,
                    height: chartHeight
                ),
                guideHeight: proxy.size.height
            )
        }
        .allowsHitTesting(false)
    }
}

struct ChartSubstrateGridView: View {
    @Environment(\.tkPalette) private var palette

    let style: TKLineChartCanvasView.VisualStyle
    let color: Color?

    init(
        style: TKLineChartCanvasView.VisualStyle,
        color: Color? = nil
    ) {
        self.style = style
        self.color = color
    }

    var body: some View {
        GeometryReader { proxy in
            let lineXPositions = ChartSubstrateGridLayout.lineXPositions(
                width: proxy.size.width,
                lineCount: ChartBottomPriceView.Layout.axisDivisionCount
            )
            ZStack(alignment: .topLeading) {
                ForEach(0 ..< lineXPositions.count, id: \.self) { index in
                    Rectangle()
                        .fill(style.gridLineGradient(color: color, palette: palette))
                        .frame(
                            width: ChartSubstrateGridStyle.lineWidth,
                            height: proxy.size.height
                        )
                        .offset(x: lineXPositions[index])
                }
            }
        }
        .allowsHitTesting(false)
    }
}

enum ChartSubstrateGridLayout {
    static func lineXPositions(width: CGFloat, lineCount: Int) -> [CGFloat] {
        guard width > 0, lineCount > 0 else { return [] }

        let offset = width / CGFloat(lineCount)
        return (0 ..< lineCount).map { index in
            (offset / 2) + (offset * CGFloat(index))
        }
    }
}

enum ChartVerticalGuideLayout {
    static var chartAndBottomHeight: CGFloat {
        combinedHeight(
            chartHeight: ChartView.Layout.chartHeight,
            bottomHeight: ChartBottomPriceView.Layout.height
        )
    }

    static func combinedHeight(chartHeight: CGFloat, bottomHeight: CGFloat) -> CGFloat {
        chartHeight + bottomHeight
    }
}

private enum ChartSubstrateGridStyle {
    static let lineWidth: CGFloat = 1
    static let lineOpacity = 0.08

    static let gradientAlphaStops: [(location: CGFloat, alpha: Double)] = [
        (0, 0),
        (0.066667, 0.009),
        (0.133333, 0.036),
        (0.2, 0.082),
        (0.266667, 0.147),
        (0.333333, 0.232),
        (0.4, 0.332),
        (0.466667, 0.443),
        (0.533333, 0.557),
        (0.6, 0.668),
        (0.666667, 0.768),
        (0.733333, 0.853),
        (0.8, 0.918),
        (0.866667, 0.964),
        (0.933333, 0.991),
        (1, 1),
    ]
}

private extension TKLineChartCanvasView.VisualStyle {
    func gridLineColor(_ palette: TKPalette) -> Color {
        switch self {
        case .active:
            return palette.separator.chart
        case .skeleton:
            return palette.background.contentTint
        }
    }

    func gridLineGradient(color overrideColor: Color? = nil, palette: TKPalette) -> LinearGradient {
        let color = overrideColor ?? gridLineColor(palette)
        return LinearGradient(
            gradient: Gradient(
                stops: ChartSubstrateGridStyle.gradientAlphaStops.map { stop in
                    Gradient.Stop(
                        color: color.opacity(stop.alpha * ChartSubstrateGridStyle.lineOpacity),
                        location: stop.location
                    )
                }
            ),
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct SkeletonPulseModifier: ViewModifier {
    let isEnabled: Bool

    func body(content: Content) -> some View {
        TimelineView(.animation(minimumInterval: Layout.frameInterval)) { context in
            content.opacity(
                isEnabled
                    ? opacity(for: context.date)
                    : Layout.maximumOpacity
            )
        }
    }
}

private extension SkeletonPulseModifier {
    func opacity(for date: Date) -> CGFloat {
        let cycleDuration = TimeInterval(Layout.duration * 2)
        let elapsed = date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: cycleDuration)
        let phase = elapsed / cycleDuration
        let pulse = 0.5 - (0.5 * cos(phase * 2 * .pi))

        return Layout.minimumOpacity + ((Layout.maximumOpacity - Layout.minimumOpacity) * pulse)
    }

    enum Layout {
        static let duration: CGFloat = 0.9
        static let frameInterval: TimeInterval = 1 / 30
        static let minimumOpacity: CGFloat = 0.55
        static let maximumOpacity: CGFloat = 1
    }
}

import KeeperCore
import SwiftUI
import TKLocalize
import TKUIKit

struct PerpsChartView: View {
    @Environment(\.tkResolvedTheme) private var resolvedTheme
    @ObservedObject var viewModel: PerpsChartViewModel
    let markers: [PerpsChartPositionMarker]
    @State private var isChartSurfaceReady = false

    init(
        viewModel: PerpsChartViewModel,
        markers: [PerpsChartPositionMarker] = []
    ) {
        self.viewModel = viewModel
        self.markers = markers
    }

    var body: some View {
        VStack(spacing: 0) {
            chartArea
                .frame(height: Layout.chartHeight)
                .frame(maxWidth: .infinity)
            timeframeRow
        }
        .onChange(of: viewModel.loadingState) { state in
            if state == .loading || state == .empty || state == .failed {
                isChartSurfaceReady = false
            }
        }
    }
}

private extension PerpsChartView {
    var showsLoader: Bool {
        switch viewModel.loadingState {
        case .loading:
            true
        case .ready:
            !isChartSurfaceReady
        case .empty, .failed:
            false
        case .reconnecting:
            !isChartSurfaceReady
        }
    }

    @ViewBuilder
    var chartArea: some View {
        switch viewModel.loadingState {
        case .empty:
            messageView(TKLocales.Perps.Chart.empty)
        case .failed:
            failedView
        case .loading, .ready, .reconnecting:
            ZStack(alignment: .topLeading) {
                PerpsChartCanvas(
                    candles: viewModel.loadingState == .loading ? [] : viewModel.candles,
                    mode: viewModel.mode,
                    priceDecimals: viewModel.priceDecimals,
                    markers: markers,
                    timeframe: viewModel.timeframe,
                    resolvedTheme: resolvedTheme,
                    onCrosshair: { viewModel.selectCandle(atTime: $0) },
                    onReachedLeftEdge: { viewModel.loadOlderCandles() },
                    onFirstPaint: {
                        guard viewModel.loadingState == .ready || viewModel.loadingState == .reconnecting else { return }
                        isChartSurfaceReady = true
                    }
                )
                .allowsHitTesting(!showsLoader)
                if showsLoader {
                    loadingView
                }
                if viewModel.loadingState == .reconnecting {
                    staleBadge
                }
            }
        }
    }

    var loadingView: some View {
        ZStack {
            CircularLoader(mode: .indeterminate, preset: .medium)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.backgroundPage)
    }

    func messageView(_ text: String) -> some View {
        Text(text)
            .textStyle(.body2)
            .foregroundStyle(.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var failedView: some View {
        VStack(spacing: Layout.failedSpacing) {
            Text(TKLocales.Perps.Chart.failed)
                .textStyle(.body2)
                .foregroundStyle(.textSecondary)
            Button(action: { viewModel.retry() }) {
                Text(TKLocales.Perps.Asset.retry)
                    .textStyle(.label2)
                    .foregroundStyle(.buttonSecondaryForeground)
                    .padding(.horizontal, Layout.retryHPadding)
                    .frame(height: Layout.retryHeight)
                    .background(Capsule().fill(.buttonSecondaryBackground))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var staleBadge: some View {
        CircularLoader(mode: .indeterminate, preset: .small)
            .padding(Layout.staleBadgeInset)
    }

    var timeframeRow: some View {
        HStack(spacing: Layout.timeframeSpacing) {
            ForEach(PerpsChartTimeframe.allCases, id: \.self) { timeframe in
                timeframeButton(timeframe)
            }
            Spacer(minLength: Layout.toggleLeadingGap)
            modeToggle
        }
        .padding(.horizontal, Layout.rowHPadding)
        .frame(height: Layout.rowHeight)
    }

    func timeframeButton(_ timeframe: PerpsChartTimeframe) -> some View {
        let isSelected = viewModel.timeframe == timeframe
        return Button(action: { viewModel.selectTimeframe(timeframe) }) {
            Text(timeframe.displayLabel)
                .textStyle(.label2)
                .foregroundStyle(.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: Layout.pillHeight)
                .background(
                    Capsule().fill(isSelected ? .backgroundContentTint : .clear)
                )
        }
        .buttonStyle(.plain)
    }

    var modeToggle: some View {
        Button(action: { viewModel.toggleMode() }) {
            ModeToggleGlyph(mode: viewModel.mode)
                .frame(width: Layout.toggleSide, height: Layout.toggleSide)
                .background(Circle().fill(.backgroundContentTint))
        }
        .buttonStyle(.plain)
    }
}

private struct ModeToggleGlyph: View {
    let mode: PerpsChartMode

    var body: some View {
        switch mode {
        case .candle:
            LineGlyph()
                .stroke(.accentGreen, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                .frame(width: 16, height: 12)
        case .line:
            HStack(spacing: 3) {
                candle(color: .accentGreen, bodyHeight: 8, offset: 1)
                candle(color: .accentRed, bodyHeight: 6, offset: -1)
            }
        }
    }

    private func candle(color: TKColor, bodyHeight: CGFloat, offset: CGFloat) -> some View {
        ZStack {
            Rectangle()
                .fill(color)
                .frame(width: 1, height: 14)
            RoundedRectangle(cornerRadius: 1)
                .fill(color)
                .frame(width: 4, height: bodyHeight)
        }
        .offset(y: offset)
    }
}

private struct LineGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let points: [CGPoint] = [
            CGPoint(x: 0, y: rect.maxY),
            CGPoint(x: rect.width * 0.33, y: rect.height * 0.35),
            CGPoint(x: rect.width * 0.6, y: rect.height * 0.6),
            CGPoint(x: rect.maxX, y: 0),
        ]
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }
}

private enum Layout {
    static let chartHeight: CGFloat = 240
    static let rowHeight: CGFloat = 68
    static let rowHPadding: CGFloat = 16
    static let timeframeSpacing: CGFloat = 0
    static let pillHeight: CGFloat = 36
    static let toggleSide: CGFloat = 36
    static let toggleLeadingGap: CGFloat = 8
    static let failedSpacing: CGFloat = 11
    static let retryHPadding: CGFloat = 16
    static let retryHeight: CGFloat = 32
    static let staleBadgeInset: CGFloat = 8
}

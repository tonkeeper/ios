import PerpsModels
import SwiftUI
import TKLocalize
import TKUIKit

@MainActor
public protocol PerpsChartViewModeling: ObservableObject {
    var loadingState: PerpsChartLoadingState { get }
    var candles: [PerpsChartCandle] { get }
    var mode: PerpsChartMode { get }
    var priceDecimals: Int { get }
    var timeframe: PerpsChartTimeframe { get }
    var crosshairReadout: PerpsChartCrosshairReadout? { get }

    func onAppear()
    func onDisappear()
    func selectCandle(atTime time: Date?, baselineTime: Date?)
    func loadOlderCandles()
    func selectTimeframe(_ newValue: PerpsChartTimeframe)
    func selectMode(_ newValue: PerpsChartMode)
    func retry()
}

public struct PerpsChartView<ViewModel: PerpsChartViewModeling>: View {
    @Environment(\.tkResolvedTheme) private var resolvedTheme
    @ObservedObject private var viewModel: ViewModel
    private let markers: [PerpsChartPositionMarker]
    @State private var isChartSurfaceReady = false

    public init(
        viewModel: ViewModel,
        markers: [PerpsChartPositionMarker] = []
    ) {
        self.viewModel = viewModel
        self.markers = markers
    }

    public var body: some View {
        VStack(spacing: 0) {
            chartArea
                .frame(height: Layout.chartHeight)
                .frame(maxWidth: .infinity)
            PerpsChartPeriodRow(
                timeframe: viewModel.timeframe,
                mode: viewModel.mode,
                onSelectTimeframe: { viewModel.selectTimeframe($0) },
                onSelectMode: { viewModel.selectMode($0) }
            )
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
                    onCrosshair: { viewModel.selectCandle(atTime: $0, baselineTime: $1) },
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
}

private enum Layout {
    static let chartHeight: CGFloat = 240
    static let failedSpacing: CGFloat = 11
    static let retryHPadding: CGFloat = 16
    static let retryHeight: CGFloat = 32
    static let staleBadgeInset: CGFloat = 8
}

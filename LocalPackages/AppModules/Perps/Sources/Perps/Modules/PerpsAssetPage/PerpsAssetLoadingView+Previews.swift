import PerpsModels
import SwiftUI
import TKUIKit

private final class PerpsChartLoadingPreviewViewModel: PerpsChartViewModeling {
    let loadingState: PerpsChartLoadingState = .loading
    let candles: [PerpsChartCandle] = []
    let mode: PerpsChartMode = .candle
    let priceDecimals = 2
    let timeframe: PerpsChartTimeframe = .h1
    let crosshairReadout: PerpsChartCrosshairReadout? = nil

    func onAppear() {}
    func onDisappear() {}
    func selectCandle(atTime time: Date?, baselineTime: Date?) {}
    func loadOlderCandles() {}
    func selectTimeframe(_ newValue: PerpsChartTimeframe) {}
    func selectMode(_ newValue: PerpsChartMode) {}
    func retry() {}
}

#Preview("Skeleton") {
    PerpsAssetLoadingView(hasPosition: false, chartViewModel: PerpsChartLoadingPreviewViewModel())
        .background(.backgroundPage)
        .tkPreviewTheme(.deepBlue)
}

#Preview("Skeleton with position") {
    PerpsAssetLoadingView(hasPosition: true, chartViewModel: PerpsChartLoadingPreviewViewModel())
        .background(.backgroundPage)
        .tkPreviewTheme(.deepBlue)
}

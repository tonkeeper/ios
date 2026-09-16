import KeeperCore
import LightweightCharts
import SwiftUI
import TKUIKit

struct PerpsChartCanvas: UIViewRepresentable {
    let candles: [PerpsChartCandle]
    let mode: PerpsChartMode
    let priceDecimals: Int
    let markers: [PerpsChartPositionMarker]
    let timeframe: PerpsChartTimeframe
    let resolvedTheme: TKResolvedTheme
    let onCrosshair: (Date?) -> Void
    let onReachedLeftEdge: () -> Void
    let onFirstPaint: () -> Void

    func makeCoordinator() -> PerpsChartRenderer {
        PerpsChartRenderer(
            onCrosshair: onCrosshair,
            onReachedLeftEdge: onReachedLeftEdge,
            onFirstPaint: onFirstPaint
        )
    }

    func makeUIView(context: Context) -> LightweightCharts {
        let chart = context.coordinator.makeChart(priceDecimals: priceDecimals, resolvedTheme: resolvedTheme)
        context.coordinator.render(
            candles: candles,
            mode: mode,
            priceDecimals: priceDecimals,
            markers: markers,
            timeframe: timeframe,
            resolvedTheme: resolvedTheme
        )
        return chart
    }

    func updateUIView(_ uiView: LightweightCharts, context: Context) {
        context.coordinator.onCrosshair = onCrosshair
        context.coordinator.onReachedLeftEdge = onReachedLeftEdge
        context.coordinator.onFirstPaint = onFirstPaint
        context.coordinator.render(
            candles: candles,
            mode: mode,
            priceDecimals: priceDecimals,
            markers: markers,
            timeframe: timeframe,
            resolvedTheme: resolvedTheme
        )
    }

    static func dismantleUIView(_ uiView: LightweightCharts, coordinator: PerpsChartRenderer) {
        coordinator.teardown(chart: uiView)
    }
}

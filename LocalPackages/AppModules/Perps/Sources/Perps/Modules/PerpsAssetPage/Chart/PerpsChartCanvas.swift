import LightweightCharts
import PerpsModels
import SwiftUI
import TKUIKit

public struct PerpsChartCanvas: UIViewRepresentable {
    let candles: [PerpsChartCandle]
    let mode: PerpsChartMode
    let priceDecimals: Int
    let markers: [PerpsChartPositionMarker]
    let timeframe: PerpsChartTimeframe
    let resolvedTheme: TKResolvedTheme
    let onCrosshair: (Date?, Date?) -> Void
    let onReachedLeftEdge: () -> Void
    let onFirstPaint: () -> Void

    public init(
        candles: [PerpsChartCandle],
        mode: PerpsChartMode,
        priceDecimals: Int,
        markers: [PerpsChartPositionMarker],
        timeframe: PerpsChartTimeframe,
        resolvedTheme: TKResolvedTheme,
        onCrosshair: @escaping (Date?, Date?) -> Void,
        onReachedLeftEdge: @escaping () -> Void,
        onFirstPaint: @escaping () -> Void
    ) {
        self.candles = candles
        self.mode = mode
        self.priceDecimals = priceDecimals
        self.markers = markers
        self.timeframe = timeframe
        self.resolvedTheme = resolvedTheme
        self.onCrosshair = onCrosshair
        self.onReachedLeftEdge = onReachedLeftEdge
        self.onFirstPaint = onFirstPaint
    }

    public func makeCoordinator() -> PerpsChartRenderer {
        PerpsChartRenderer(
            onCrosshair: onCrosshair,
            onReachedLeftEdge: onReachedLeftEdge,
            onFirstPaint: onFirstPaint
        )
    }

    public func makeUIView(context: Context) -> LightweightCharts {
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

    public func updateUIView(_ uiView: LightweightCharts, context: Context) {
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

    public static func dismantleUIView(_ uiView: LightweightCharts, coordinator: PerpsChartRenderer) {
        coordinator.teardown(chart: uiView)
    }
}

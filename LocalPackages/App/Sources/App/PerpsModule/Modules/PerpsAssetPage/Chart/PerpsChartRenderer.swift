import KeeperCore
import LightweightCharts
import TKUIKit
import UIKit

final class PerpsChartRenderer: NSObject, ChartDelegate, TimeScaleDelegate {
    var onCrosshair: (Date?) -> Void
    var onReachedLeftEdge: () -> Void
    var onFirstPaint: () -> Void

    private weak var chart: LightweightCharts?
    private var candleSeries: RoundedCandlestickSeries?
    private var volumeSeries: RoundedHistogramSeries?
    private var areaSeries: AreaSeries?
    private var markersPlugin: (any PriceLevelMarkersControlling)?
    private var activeMarkersMode: PerpsChartMode?

    private var renderedCandles: [PerpsChartCandle] = []
    private var renderedMode: PerpsChartMode?
    private var renderedTimeframe: PerpsChartTimeframe?
    private var renderedMarkersState: RenderedMarkersState?
    private var lastCrosshairTimestamp: TimeInterval?
    private var lastLogicalRange: LogicalRange?
    private var isArmedForOlderLoad = true
    private var priceDecimals = 2
    private var resolvedTheme: TKResolvedTheme?
    private var didNotifyFirstPaint = false
    private var paintGeneration = 0

    private static let loadOlderThresholdBars: Double = 10

    init(
        onCrosshair: @escaping (Date?) -> Void,
        onReachedLeftEdge: @escaping () -> Void = {},
        onFirstPaint: @escaping () -> Void = {}
    ) {
        self.onCrosshair = onCrosshair
        self.onReachedLeftEdge = onReachedLeftEdge
        self.onFirstPaint = onFirstPaint
    }

    func makeChart(priceDecimals: Int, resolvedTheme: TKResolvedTheme) -> LightweightCharts {
        self.priceDecimals = priceDecimals
        self.resolvedTheme = resolvedTheme

        let chart = LightweightCharts(options: Self.chartOptions(resolvedTheme: resolvedTheme))
        chart.delegate = self
        // The web view is opaque-black until the chart's first paint. Make it
        // transparent over a page-colored host so the bootstrap window shows the
        // page background instead of a black flash when the loader hands off.
        chart.backgroundColor = Self.uiColor(.backgroundPage, resolvedTheme: resolvedTheme)
        chart.clearWebViewBackground()

        let candles = chart.addRoundedCandlestickSeries(
            options: Self.candlestickOptions(priceDecimals: priceDecimals, resolvedTheme: resolvedTheme)
        )
        candleSeries = candles

        let volume = chart.addRoundedHistogramSeries(
            options: Self.volumeOptions(resolvedTheme: resolvedTheme)
        )
        volume.priceScale().applyOptions(options: PriceScaleOptions(
            scaleMargins: Self.volumeScaleMargins
        ))
        volumeSeries = volume

        let area = chart.addAreaSeries(
            options: Self.areaOptions(priceDecimals: priceDecimals, resolvedTheme: resolvedTheme)
        )
        areaSeries = area

        chart.subscribeCrosshairMove()
        chart.timeScale().delegate = self
        chart.timeScale().subscribeVisibleLogicalRangeChange()
        self.chart = chart
        return chart
    }

    func render(
        candles: [PerpsChartCandle],
        mode: PerpsChartMode,
        priceDecimals: Int,
        markers: [PerpsChartPositionMarker],
        timeframe: PerpsChartTimeframe,
        resolvedTheme: TKResolvedTheme
    ) {
        if resolvedTheme != self.resolvedTheme {
            applyTheme(resolvedTheme)
        }

        let priceDecimalsChanged = priceDecimals != self.priceDecimals
        self.priceDecimals = priceDecimals
        if priceDecimalsChanged {
            applyPriceFormat(priceDecimals)
            applyMarkerOptions(for: mode, resolvedTheme: resolvedTheme)
            renderedMarkersState = nil
        }

        let modeChanged = mode != renderedMode
        if modeChanged {
            clearInactiveSeries(for: mode)
            applyAxes(for: mode)
            renderedMode = mode
            renderedCandles = []
            renderedMarkersState = nil
        }
        let timeframeChanged = timeframe != renderedTimeframe
        if timeframeChanged {
            paintGeneration += 1
            didNotifyFirstPaint = false
        }

        // Line mode is tag-free: no position lines and no current-price bubble.
        let displayedMarkers = mode == .line
            ? []
            : Self.displayedMarkers(markers, latestCandle: candles.last)
        render(markers: displayedMarkers, mode: mode, resolvedTheme: resolvedTheme)
        guard candles != renderedCandles else { return }

        if !renderedCandles.isEmpty, isTailExtension(of: renderedCandles, new: candles) {
            applyTail(from: renderedCandles.count - 1, candles: candles, mode: mode)
        } else {
            let prepended = timeframeChanged ? 0 : prependedBarCount(old: renderedCandles, new: candles)
            applyFull(candles: candles, mode: mode)
            if timeframeChanged {
                chart?.timeScale().resetTimeScale()
            } else if prepended > 0, let last = lastLogicalRange {
                chart?.timeScale().setVisibleLogicalRange(
                    range: FromToRange(from: last.from + Double(prepended), to: last.to + Double(prepended))
                )
            }
        }
        renderedCandles = candles
        renderedTimeframe = timeframe
        notifyFirstPaintIfNeeded()
    }

    private func notifyFirstPaintIfNeeded() {
        guard !didNotifyFirstPaint, !renderedCandles.isEmpty, let chart else { return }
        didNotifyFirstPaint = true
        let generation = paintGeneration
        chart.onLoadError { [weak self] _, _ in
            guard let self, generation == self.paintGeneration else { return }
            self.onFirstPaint()
        }
        let queued = chart.whenReady { [weak self] chart in
            Task { @MainActor [weak self] in
                // setData is fire-and-forget; this round-trip waits until that JS has run.
                _ = try? await chart.autoSizeActive()
                guard let self, generation == self.paintGeneration else { return }
                self.onFirstPaint()
            }
        }
        if !queued, generation == paintGeneration {
            onFirstPaint()
        }
    }

    private func prependedBarCount(old: [PerpsChartCandle], new: [PerpsChartCandle]) -> Int {
        guard let oldFirst = old.first, new.count > old.count else { return 0 }
        guard let index = new.firstIndex(where: { $0.openedAt == oldFirst.openedAt }) else { return 0 }
        return index
    }

    func teardown(chart: LightweightCharts) {
        paintGeneration += 1
        detachMarkersPlugin()
        chart.timeScale().unsubscribeVisibleLogicalRangeChange()
        chart.timeScale().delegate = nil
        chart.delegate = nil
        chart.removeFromSuperview()
        onFirstPaint = {}
        didNotifyFirstPaint = false
        self.chart = nil
        candleSeries = nil
        volumeSeries = nil
        areaSeries = nil
        renderedCandles = []
        renderedMode = nil
        renderedTimeframe = nil
        renderedMarkersState = nil
        lastCrosshairTimestamp = nil
        lastLogicalRange = nil
        isArmedForOlderLoad = true
        resolvedTheme = nil
    }

    func didVisibleTimeRangeChange(onTimeScale timeScale: TimeScaleApi, parameters: TimeRange?) {}

    func didVisibleLogicalRangeChange(onTimeScale timeScale: TimeScaleApi, parameters: LogicalRange?) {
        guard let range = parameters else { return }
        lastLogicalRange = range
        guard renderedMode == .candle else { return }
        if range.from >= Self.loadOlderThresholdBars {
            isArmedForOlderLoad = true
        } else if isArmedForOlderLoad {
            isArmedForOlderLoad = false
            onReachedLeftEdge()
        }
    }

    func didReceiveTimeScaleSizeChangeWithParameters(onTimeScale timeScale: TimeScaleApi, parameters: Rectangle?) {}

    // MARK: ChartDelegate

    func didClick(onChart chart: ChartApi, parameters: MouseEventParams) {}

    func didCrosshairMove(onChart chart: ChartApi, parameters: MouseEventParams) {
        guard case let .utc(timestamp)? = parameters.time, parameters.point != nil else {
            guard lastCrosshairTimestamp != nil else { return }
            lastCrosshairTimestamp = nil
            onCrosshair(nil)
            return
        }
        guard timestamp != lastCrosshairTimestamp else { return }
        lastCrosshairTimestamp = timestamp
        onCrosshair(Date(timeIntervalSince1970: timestamp))
    }

    // MARK: Rendering helpers

    private func clearInactiveSeries(for mode: PerpsChartMode) {
        switch mode {
        case .candle:
            areaSeries?.setData(data: [AreaData]())
        case .line:
            candleSeries?.setData(data: [RoundedCandlestickData]())
            volumeSeries?.setData(data: [RoundedHistogramData]())
        }
    }

    private func applyFull(candles: [PerpsChartCandle], mode: PerpsChartMode) {
        switch mode {
        case .candle:
            candleSeries?.setData(data: candles.map(Self.candlestickData))
            volumeSeries?.setData(data: candles.compactMap(Self.volumeData))
        case .line:
            areaSeries?.setData(data: candles.map(Self.areaData))
        }
    }

    private func applyTail(from startIndex: Int, candles: [PerpsChartCandle], mode: PerpsChartMode) {
        guard startIndex >= 0 else { return }
        for index in startIndex ..< candles.count {
            let candle = candles[index]
            switch mode {
            case .candle:
                candleSeries?.update(bar: Self.candlestickData(candle))
                if let volume = Self.volumeData(candle) {
                    volumeSeries?.update(bar: volume)
                }
            case .line:
                areaSeries?.update(bar: Self.areaData(candle))
            }
        }
    }

    private func render(
        markers: [PerpsChartPositionMarker],
        mode: PerpsChartMode,
        resolvedTheme: TKResolvedTheme
    ) {
        let state = RenderedMarkersState(mode: mode, markers: markers)
        guard state != renderedMarkersState else { return }

        ensureMarkersPlugin(for: mode, resolvedTheme: resolvedTheme)
        markersPlugin?.setMarkers(Self.priceLevelMarkers(markers, resolvedTheme: resolvedTheme))
        renderedMarkersState = state
    }

    private func ensureMarkersPlugin(for mode: PerpsChartMode, resolvedTheme: TKResolvedTheme) {
        guard activeMarkersMode != mode else { return }

        detachMarkersPlugin()

        let options = Self.priceLevelMarkersOptions(
            priceDecimals: priceDecimals,
            mode: mode,
            resolvedTheme: resolvedTheme
        )
        switch mode {
        case .candle:
            guard let candleSeries else { return }
            markersPlugin = PriceLevelMarkersPlugin(series: candleSeries, options: options)
        case .line:
            guard let areaSeries else { return }
            markersPlugin = PriceLevelMarkersPlugin(series: areaSeries, options: options)
        }
        activeMarkersMode = mode
    }

    private func applyMarkerOptions(for mode: PerpsChartMode, resolvedTheme: TKResolvedTheme) {
        markersPlugin?.applyOptions(
            options: Self.priceLevelMarkersOptions(
                priceDecimals: priceDecimals,
                mode: mode,
                resolvedTheme: resolvedTheme
            )
        )
    }

    private func applyPriceFormat(_ priceDecimals: Int) {
        var candleOptions = RoundedCandlestickSeries.Options()
        candleOptions.priceFormat = Self.priceFormat(priceDecimals)
        candleSeries?.applyOptions(options: candleOptions)

        var areaOptions = AreaSeries.Options()
        areaOptions.priceFormat = Self.priceFormat(priceDecimals)
        areaSeries?.applyOptions(options: areaOptions)
    }

    private func applyTheme(_ resolvedTheme: TKResolvedTheme) {
        self.resolvedTheme = resolvedTheme
        chart?.applyOptions(options: Self.themeColorOptions(resolvedTheme: resolvedTheme))
        chart?.backgroundColor = Self.uiColor(.backgroundPage, resolvedTheme: resolvedTheme)
        chart?.clearWebViewBackground()

        candleSeries?.applyOptions(
            options: Self.candlestickOptions(priceDecimals: priceDecimals, resolvedTheme: resolvedTheme)
        )
        volumeSeries?.applyOptions(options: Self.volumeOptions(resolvedTheme: resolvedTheme))
        areaSeries?.applyOptions(
            options: Self.areaOptions(priceDecimals: priceDecimals, resolvedTheme: resolvedTheme)
        )
        if let renderedMode {
            applyMarkerOptions(for: renderedMode, resolvedTheme: resolvedTheme)
        }
        renderedMarkersState = nil
    }

    /// Line mode hides the right price scale (a 0-width scale still reserves room
    /// for its transparent labels, leaving a gap); candle keeps the price-ladder
    /// gutter. Both pin the latest bar flush to the right edge so neither scrolls
    /// into empty space; line also pins the left edge to fill the width.
    private func applyAxes(for mode: PerpsChartMode) {
        let isLine = mode == .line
        chart?.priceScale(priceScaleId: Self.rightPriceScaleId).applyOptions(options: PriceScaleOptions(
            visible: !isLine,
            minimumWidth: isLine ? 0 : Self.customPriceAxisMinimumWidth
        ))
        chart?.timeScale().applyOptions(options: TimeScaleOptions(
            rightOffset: 0,
            fixLeftEdge: isLine,
            fixRightEdge: true
        ))
    }

    private func detachMarkersPlugin() {
        markersPlugin?.detach()
        markersPlugin = nil
        activeMarkersMode = nil
    }

    private func isTailExtension(of old: [PerpsChartCandle], new: [PerpsChartCandle]) -> Bool {
        guard !old.isEmpty, new.count >= old.count else { return false }
        for index in 0 ..< (old.count - 1) where old[index] != new[index] {
            return false
        }
        // The overlapping last bar may update in value, but it must be the same bar
        // (same open time); a different time means the tail was replaced and needs
        // a full reset, not an in-place update.
        return old[old.count - 1].openedAt == new[old.count - 1].openedAt
    }

    // MARK: Data mapping

    private static func time(_ candle: PerpsChartCandle) -> Time {
        .utc(timestamp: candle.openedAt.timeIntervalSince1970)
    }

    private static func candlestickData(_ candle: PerpsChartCandle) -> RoundedCandlestickData {
        RoundedCandlestickData(
            time: time(candle),
            open: candle.open,
            high: candle.high,
            low: candle.low,
            close: candle.close
        )
    }

    private static func areaData(_ candle: PerpsChartCandle) -> AreaData {
        AreaData(time: time(candle), value: candle.close)
    }

    private static func volumeData(_ candle: PerpsChartCandle) -> RoundedHistogramData? {
        guard let volume = candle.volume else { return nil }
        return RoundedHistogramData(time: time(candle), value: volume)
    }

    private static func priceLevelMarkers(
        _ markers: [PerpsChartPositionMarker],
        resolvedTheme: TKResolvedTheme
    ) -> [PriceLevelMarker] {
        markers.map { marker in
            PriceLevelMarker(
                id: "\(marker.kind)",
                price: marker.price,
                title: marker.kind == .currentPrice ? nil : marker.title,
                color: chartColor(marker.color, resolvedTheme: resolvedTheme),
                lineColor: chartColor(marker.color, resolvedTheme: resolvedTheme),
                backgroundColor: ChartColor(marker.backgroundColor(resolvedTheme: resolvedTheme)),
                align: marker.alignment == .right ? .right : .left,
                lineVisible: true,
                direction: marker.direction.map {
                    $0 == .up ? PriceLevelMarker.Direction.up : .down
                },
                isCurrentPrice: marker.kind == .currentPrice
            )
        }
    }

    private static func displayedMarkers(
        _ markers: [PerpsChartPositionMarker],
        latestCandle: PerpsChartCandle?
    ) -> [PerpsChartPositionMarker] {
        var result = markers.filter { $0.kind != .currentPrice }
        if let marker = currentPriceMarker(latestCandle) {
            result.append(marker)
        }
        return result
    }

    private static func currentPriceMarker(
        _ candle: PerpsChartCandle?
    ) -> PerpsChartPositionMarker? {
        guard let candle else { return nil }
        return PerpsChartPositionMarker(
            kind: .currentPrice,
            price: candle.close,
            direction: candle.close >= candle.open ? .up : .down
        )
    }

    static func priceLevelMarkersOptions(
        priceDecimals: Int,
        mode: PerpsChartMode,
        resolvedTheme: TKResolvedTheme
    ) -> PriceLevelMarkersOptions {
        let isLine = mode == .line
        return PriceLevelMarkersOptions(
            priceDecimals: priceDecimals,
            currentPriceUpLabelColor: chartColor(.accentGreen, resolvedTheme: resolvedTheme),
            currentPriceUpLabelBackgroundColor: labelBackground(.accentGreen, resolvedTheme: resolvedTheme),
            currentPriceDownLabelColor: chartColor(.accentRed, resolvedTheme: resolvedTheme),
            currentPriceDownLabelBackgroundColor: labelBackground(.accentRed, resolvedTheme: resolvedTheme),
            axisLabelColor: chartColor(.textSecondary, resolvedTheme: resolvedTheme),
            dotHaloColor: chartColor(.constantWhite.opacity(0.16), resolvedTheme: resolvedTheme),
            dotColor: chartColor(.constantWhite, resolvedTheme: resolvedTheme),
            crosshairColor: chartColor(.constantWhite, resolvedTheme: resolvedTheme),
            crosshairLabelColor: chartColor(.constantWhite, resolvedTheme: resolvedTheme),
            crosshairLabelBackgroundColor: labelBackground(.constantWhite, resolvedTheme: resolvedTheme),
            gridColor: chartColor(.separatorCommon, resolvedTheme: resolvedTheme),
            // Line mode: dot snaps onto the line; no horizontal crosshair or axis bubble.
            axisLabelMode: isLine ? .bounds : .ladder,
            crosshairHorizontalVisible: !isLine,
            crosshairLabelVisible: !isLine,
            crosshairDotOnSeries: isLine
        )
    }

    // MARK: Theme

    static let volumeScaleId = "volume"
    private static let rightPriceScaleId = "right"
    private static let customPriceAxisMinimumWidth: Double = 88
    private static let defaultBarSpacing: Double = 12
    // Volume occupies the bottom sliver; the price series leaves room above it.
    private static let volumeScaleMargins = PriceScaleMargins(top: 0.86, bottom: 0.02)
    private static let mainScaleMargins = PriceScaleMargins(top: 0.1, bottom: 0.22)

    static func candlestickOptions(
        priceDecimals: Int,
        resolvedTheme: TKResolvedTheme
    ) -> RoundedCandlestickSeries.Options {
        var options = RoundedCandlestickSeries.Options()
        options.priceFormat = priceFormat(priceDecimals)
        options.priceLineVisible = false
        options.lastValueVisible = false
        options.priceLineSource = .lastBar
        options.upColor = chartColor(.accentGreen, resolvedTheme: resolvedTheme)
        options.downColor = chartColor(.accentRed, resolvedTheme: resolvedTheme)
        options.wickVisible = true
        options.wickUpColor = chartColor(.accentGreen, resolvedTheme: resolvedTheme)
        options.wickDownColor = chartColor(.accentRed, resolvedTheme: resolvedTheme)
        options.bodyMinHeight = 2
        options.radius = 3
        return options
    }

    static func volumeOptions(resolvedTheme: TKResolvedTheme) -> RoundedHistogramSeries.Options {
        var options = RoundedHistogramSeries.Options()
        options.priceScaleId = Self.volumeScaleId
        options.priceFormat = PriceFormat.builtIn(
            BuiltInPriceFormat(type: .volume, precision: nil, minMove: nil)
        )
        options.color = chartColor(.backgroundContentTint, resolvedTheme: resolvedTheme)
        options.lastValueVisible = false
        options.priceLineVisible = false
        options.barMinHeight = 3
        options.radius = 3
        return options
    }

    static func areaOptions(
        priceDecimals: Int,
        resolvedTheme: TKResolvedTheme
    ) -> AreaSeries.Options {
        var options = AreaSeries.Options()
        options.priceFormat = priceFormat(priceDecimals)
        options.lineColor = chartColor(.accentGreen, resolvedTheme: resolvedTheme)
        options.topColor = chartColor(.accentGreen.opacity(0.32), resolvedTheme: resolvedTheme)
        options.bottomColor = chartColor(.accentGreen.opacity(0), resolvedTheme: resolvedTheme)
        options.lineWidth = .two
        options.priceLineVisible = false
        options.lastValueVisible = false
        return options
    }

    private static func minMove(_ priceDecimals: Int) -> Double {
        guard priceDecimals > 0 else { return 1 }
        return pow(10, -Double(priceDecimals))
    }

    private static func priceFormat(_ priceDecimals: Int) -> PriceFormat {
        .builtIn(
            BuiltInPriceFormat(type: .price, precision: Double(priceDecimals), minMove: minMove(priceDecimals))
        )
    }

    static func chartOptions(resolvedTheme: TKResolvedTheme) -> ChartOptions {
        var options = ChartOptions()
        options.layout = layoutOptions(resolvedTheme: resolvedTheme)
        options.rightPriceScale = VisiblePriceScaleOptions(
            scaleMargins: Self.mainScaleMargins,
            borderVisible: false,
            // Transparent — the markers plugin draws its own axis labels; the scale
            // only reserves `minimumWidth` to leave room for them.
            textColor: ChartColor("rgba(137, 148, 163, 0)"),
            ticksVisible: false,
            minimumWidth: customPriceAxisMinimumWidth
        )
        // Crosshair tracks the finger and clears on lift, instead of lingering
        // until the next tap (the touch-device default).
        options.trackingMode = TrackingModeOptions(exitMode: .onTouchEnd)
        // Pinch-zoom and horizontal pan are unaffected.
        options.handleScroll = .options(HandleScrollOptions.Options(vertTouchDrag: false))
        options.timeScale = TimeScaleOptions(
            rightOffset: 0,
            barSpacing: defaultBarSpacing,
            borderVisible: false,
            timeVisible: true
        )
        options.crosshair = crosshairOptions(resolvedTheme: resolvedTheme)
        options.grid = gridOptions(resolvedTheme: resolvedTheme)
        return options
    }

    /// Only the color-bearing options, for re-applying on a theme switch without
    /// disturbing stateful fields like `timeScale` (bar spacing / right offset),
    /// which a full `applyOptions` would reset to defaults, snapping the user's
    /// zoom and scroll back.
    private static func themeColorOptions(resolvedTheme: TKResolvedTheme) -> ChartOptions {
        var options = ChartOptions()
        options.layout = layoutOptions(resolvedTheme: resolvedTheme)
        options.crosshair = crosshairOptions(resolvedTheme: resolvedTheme)
        options.grid = gridOptions(resolvedTheme: resolvedTheme)
        return options
    }

    private static func layoutOptions(resolvedTheme: TKResolvedTheme) -> LayoutOptions {
        LayoutOptions(
            background: .solid(color: chartColor(.backgroundPage, resolvedTheme: resolvedTheme)),
            textColor: chartColor(.textSecondary, resolvedTheme: resolvedTheme),
            fontSize: 12,
            fontFamily: "SFMono-Semibold, SF Mono, SFMono-Regular, ui-monospace, monospace",
            attributionLogo: false
        )
    }

    private static func crosshairOptions(resolvedTheme: TKResolvedTheme) -> CrosshairOptions {
        let line = CrosshairLineOptions(
            color: chartColor(.iconSecondary, resolvedTheme: resolvedTheme),
            width: .one,
            style: .dashed,
            visible: false,
            labelVisible: false
        )
        return CrosshairOptions(mode: .normal, vertLine: line, horzLine: line)
    }

    private static func gridOptions(resolvedTheme: TKResolvedTheme) -> GridOptions {
        let line = GridLineOptions(
            color: chartColor(.separatorCommon, resolvedTheme: resolvedTheme),
            style: nil,
            visible: false
        )
        return GridOptions(verticalLines: line, horizontalLines: line)
    }

    private static func chartColor(_ color: TKColor, resolvedTheme: TKResolvedTheme) -> ChartColor {
        ChartColor(uiColor(color, resolvedTheme: resolvedTheme))
    }

    /// Opaque label fill: the token composited at 0.16 over the page color (Figma:
    /// Accent/X over Background/Page), matching `PerpsChartPositionMarker`.
    private static func labelBackground(_ color: TKColor, resolvedTheme: TKResolvedTheme) -> ChartColor {
        ChartColor(
            uiColor(color, resolvedTheme: resolvedTheme).composited(
                over: uiColor(.backgroundPage, resolvedTheme: resolvedTheme),
                alpha: 0.16
            )
        )
    }

    private static func uiColor(_ color: TKColor, resolvedTheme: TKResolvedTheme) -> UIColor {
        UIColor(color.resolve(resolvedTheme.palette))
    }
}

private struct RenderedMarkersState: Equatable {
    let mode: PerpsChartMode
    let markers: [PerpsChartPositionMarker]
}

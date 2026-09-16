import Foundation

@MainActor
public extension SeriesApi where Self: SeriesObject {
    // MARK: - Synchronous methods

    var dataChangedEvents: AsyncStream<DataChangedScope> {
        makeDataChangedStream()
    }

    func priceFormatter() -> PriceFormatterApi {
        let priceFormatter = PriceFormatter(context: context)
        let script = "window['\(priceFormatter.jsName)'] = \(jsName).priceFormatter();"
        context?.submitScript(script)
        return priceFormatter
    }

    func applyOptions(options: Options) {
        let optionsScript = options.optionsScript(for: closureStore)
        let script = """
        \(optionsScript.options)
        \(jsName).applyOptions(\(optionsScript.variableName));
        """
        context?.submitScript(script)
    }

    func priceScale() -> PriceScaleApi {
        let priceScale = PriceScale(context: context)
        let script = "window['\(priceScale.jsName)'] = \(jsName).priceScale();"
        context?.submitScript(script)
        return priceScale
    }

    func setData(data: [TickValue]) {
        setSeriesData(data)
    }

    func setData(data: [WhitespaceData]) {
        setSeriesData(data)
    }

    func setData(data: [SeriesDataType<TickValue>]) {
        setSeriesData(data)
    }

    func update(bar: TickValue, historicalUpdate: Bool? = nil) {
        updateSeriesBar(bar, historicalUpdate: historicalUpdate)
    }

    func update(bar: WhitespaceData, historicalUpdate: Bool? = nil) {
        updateSeriesBar(bar, historicalUpdate: historicalUpdate)
    }

    func update(bar: SeriesDataType<TickValue>, historicalUpdate: Bool? = nil) {
        updateSeriesBar(bar, historicalUpdate: historicalUpdate)
    }

    func setMarkers(data: [SeriesMarker]) {
        // v5 compatibility: use createSeriesMarkers primitive
        // Store plugin reference on series object as _lwcMarkersPlugin
        let script = """
        if (typeof \(jsName)._lwcMarkersPlugin === 'undefined') {
            \(jsName)._lwcMarkersPlugin = LightweightCharts.createSeriesMarkers(\(jsName), \(data.jsonString));
        } else {
            if (typeof \(jsName)._lwcMarkersPlugin.setMarkers === 'function') {
                \(jsName)._lwcMarkersPlugin.setMarkers(\(data.jsonString));
            } else if (typeof \(jsName)._lwcMarkersPlugin.setData === 'function') {
                \(jsName)._lwcMarkersPlugin.setData(\(data.jsonString));
            }
        }
        """
        context?.submitScript(script)
    }

    func createPriceLine(options: PriceLineOptions?) -> PriceLine {
        let priceLine = PriceLine(context: context)
        let options = options ?? PriceLineOptions()
        let script = "window['\(priceLine.jsName)'] = \(jsName).createPriceLine(\(options.jsonString));"
        context?.submitScript(script)
        return priceLine
    }

    func removePriceLine(line: PriceLine) {
        let script = "\(jsName).removePriceLine(\(line.jsName));"
        context?.submitScript(script)
    }

    func setSeriesOrder(order: Int) {
        let script = "\(jsName).setSeriesOrder(\(order));"
        context?.submitScript(script)
    }

    func moveToPane(paneIndex: Int) async throws(JavaScriptBridgeError) {
        let script = "\(jsName).moveToPane(\(paneIndex));"
        _ = try await requireContext().evaluateScript(script)
    }

    func subscribeDataChanged() {
        subscribeToDataChanged()
    }

    func unsubscribeDataChanged() {
        unsubscribeFromDataChanged()
    }

    // MARK: - Async methods (Swift 6)

    func priceToCoordinate(price: Double) async throws(JavaScriptBridgeError) -> Coordinate? {
        let script = "\(jsName).priceToCoordinate(\(price));"
        return try await requireContext().decodedResult(forScript: script)
    }

    func coordinateToPrice(coordinate: Double) async throws(JavaScriptBridgeError) -> BarPrice? {
        let script = "\(jsName).coordinateToPrice(\(coordinate));"
        return try await requireContext().decodedResult(forScript: script)
    }

    func barsInLogicalRange(range: FromToRange<Double>?) async throws(JavaScriptBridgeError) -> BarsInfo? {
        let rangeValue = range?.jsonString ?? "null"
        let script = "\(jsName).barsInLogicalRange(\(rangeValue));"
        return try await requireContext().decodedResult(forScript: script)
    }

    func options() async throws(JavaScriptBridgeError) -> Options {
        let script = "\(jsName).options();"
        return try await requireContext().decodedResult(forScript: script)
    }

    func data() async throws(JavaScriptBridgeError) -> [TickValue] {
        let script = "\(jsName).data();"
        return try await requireContext().decodedResult(forScript: script)
    }

    func dataByIndex(logicalIndex: Int, mismatchDirection: MismatchDirection? = nil) async throws(JavaScriptBridgeError) -> TickValue? {
        let direction = mismatchDirection?.rawValue ?? 0
        let script = "\(jsName).dataByIndex(\(logicalIndex), \(direction));"
        return try await requireContext().decodedResult(forScript: script)
    }

    func markers() async throws(JavaScriptBridgeError) -> [SeriesMarker] {
        let script = """
        (typeof \(jsName)._lwcMarkersPlugin !== 'undefined') ? \(jsName)._lwcMarkersPlugin.markers() : null;
        """
        return try await requireContext().decodedResult(forScript: script) ?? []
    }

    func priceLines() async throws(JavaScriptBridgeError) -> [PriceLine] {
        let countScript = "\(jsName).priceLines().length;"
        let context = try requireContext()
        let count = try await context.evaluate(script: countScript, resultType: Int.self)
        guard count > 0 else {
            return []
        }

        var lines: [PriceLine] = []
        for index in 0 ..< count {
            let priceLine = PriceLine(context: context)
            let createScript = "window['\(priceLine.jsName)'] = \(jsName).priceLines()[\(index)];"
            _ = try await context.evaluateScript(createScript)
            lines.append(priceLine)
        }
        return lines
    }

    func seriesType() async throws(JavaScriptBridgeError) -> SeriesType {
        let script = "\(jsName).seriesType();"
        return try await requireContext().decodedResult(forScript: script)
    }

    func seriesOrder() async throws(JavaScriptBridgeError) -> Int {
        let script = "\(jsName).seriesOrder();"
        return try await requireContext().evaluate(script: script, resultType: Int.self)
    }

    func pop(count: Int) async throws(JavaScriptBridgeError) -> [TickValue] {
        let script = "\(jsName).pop(\(count));"
        return try await requireContext().decodedResult(forScript: script)
    }

    func lastValueData(globalLast: Bool) async throws(JavaScriptBridgeError) -> LastValueDataResult {
        let script = "\(jsName).lastValueData(\(globalLast ? "true" : "false"));"
        return try await requireContext().decodedResult(forScript: script)
    }

    func getPane() async throws(JavaScriptBridgeError) -> PaneApi {
        guard let chartJSName else {
            throw JavaScriptBridgeError.evaluationFailed(script: "\(jsName).getPane().paneIndex();", message: "Series is not associated with a chart handle.")
        }

        let script = "\(jsName).getPane().paneIndex();"
        let context = try requireContext()
        let paneIndex = try await context.evaluate(script: script, resultType: Int.self)
        return Pane(index: paneIndex, chartJSName: chartJSName, context: context, closureStore: closureStore)
    }

    // MARK: - Private helpers

    private func setSeriesData<T: SeriesData>(_ data: [T]) {
        let script = "\(jsName).setData(\(data.jsonString));"
        context?.submitScript(script)
    }

    private func updateSeriesBar<T: SeriesData>(_ bar: T, historicalUpdate: Bool?) {
        var script = "\(jsName).update(\(bar.jsonString)"
        if let historicalUpdate {
            script += ", \(historicalUpdate ? "true" : "false")"
        }
        script += ");"
        context?.submitScript(script)
    }

    // MARK: - Plugin Factories

    /// Creates a new series markers plugin attached to this series.
    ///
    /// The plugin provides explicit control over markers, including setting/getting markers
    /// and applying options at runtime. Use the plugin's `detach()` method to remove it
    /// when no longer needed.
    /// Immediate follow-up plugin calls are safe because creation and later mutations are
    /// submitted to the same main-actor bridge in call order.
    ///
    /// - Parameters:
    ///   - data: Initial marker data to display.
    ///   - options: Optional initial plugin options.
    /// - Returns: A new `SeriesMarkersPlugin` instance attached to this series.
    func createMarkersPlugin(
        data: [SeriesMarker],
        options: SeriesMarkersOptions = SeriesMarkersOptions()
    ) -> SeriesMarkersPlugin<Self> {
        return SeriesMarkersPlugin(series: self, data: data, options: options)
    }
}

public extension SeriesApi where Self: UpDownMarkersSupported {
    /// Creates a new up-down markers plugin attached to this series.
    ///
    /// The plugin provides visual indicators for directional price movements.
    /// Use the plugin's `detach()` method to remove it when no longer needed.
    /// Immediate follow-up plugin calls are safe because creation and later mutations are
    /// submitted to the same main-actor bridge in call order.
    ///
    /// - Parameters:
    ///   - data: Initial marker data to display.
    ///   - options: Optional initial plugin options.
    /// - Returns: A new `UpDownMarkersPlugin` instance attached to this series.
    func createUpDownMarkersPlugin(
        data: [SeriesUpDownMarker]? = nil,
        options: UpDownMarkersOptions = UpDownMarkersOptions()
    ) -> UpDownMarkersPlugin<Self> {
        return UpDownMarkersPlugin(series: self, data: data, options: options)
    }
}

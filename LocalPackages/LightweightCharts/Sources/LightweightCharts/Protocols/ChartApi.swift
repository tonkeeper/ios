import UIKit

@MainActor
public protocol PaneApi: AnyObject {
    // Async methods throw `JavaScriptBridgeError` when the bridge context is unavailable,
    // the JavaScript evaluation fails, the result shape is invalid, decoding fails, or
    // the caller cancels the operation.

    /**
     * Sets the height of this pane in pixels.
     * - Parameter height: the desired height
     */
    func setHeight(height: Double) async throws(JavaScriptBridgeError)

    /**
     * Moves this pane to the specified index.
     * - Parameter paneIndex: the target pane index
     */
    func moveTo(paneIndex: Int) async throws(JavaScriptBridgeError)

    /**
     * Sets whether this pane should be preserved when it has no series.
     * - Parameter preserve: true to keep the pane even when empty
     */
    func setPreserveEmptyPane(preserve: Bool) async throws(JavaScriptBridgeError)

    /**
     * Sets the stretch factor of this pane.
     * - Parameter stretchFactor: the desired stretch factor
     */
    func setStretchFactor(stretchFactor: Double) async throws(JavaScriptBridgeError)

    @discardableResult
    func addAreaSeries(options: AreaSeries.Options?) -> AreaSeries

    @discardableResult
    func addBarSeries(options: BarSeries.Options?) -> BarSeries

    @discardableResult
    func addCandlestickSeries(options: CandlestickSeries.Options?) -> CandlestickSeries

    @discardableResult
    func addHistogramSeries(options: HistogramSeries.Options?) -> HistogramSeries

    @discardableResult
    func addLineSeries(options: LineSeries.Options?) -> LineSeries

    @discardableResult
    func addBaselineSeries(options: BaselineSeries.Options?) -> BaselineSeries

    /**
     * Returns the price scale API for the given price scale ID within this pane.
     * - Parameter priceScaleId: the ID of the price scale
     * - Returns: the price scale API
     */
    func priceScale(priceScaleId: String) -> PriceScaleApi

    /**
     * Returns the size of this pane.
     * - Returns: the pane size as a Rectangle
     */
    func size() async throws(JavaScriptBridgeError) -> Rectangle

    /**
     * Returns the height of this pane in pixels.
     * - Returns: the pane height
     */
    func getHeight() async throws(JavaScriptBridgeError) -> Double

    /**
     * Returns whether this pane is preserved when it has no series.
     * - Returns: true if the pane is preserved when empty
     */
    func preserveEmptyPane() async throws(JavaScriptBridgeError) -> Bool

    /**
     * Returns the stretch factor of this pane.
     * - Returns: the stretch factor value
     */
    func getStretchFactor() async throws(JavaScriptBridgeError) -> Double

    /**
     * Returns the current live index of this pane within the chart.
     * - Returns: the pane's current index
     */
    func paneIndex() async throws(JavaScriptBridgeError) -> Int

    /**
     * Returns the series attached to this pane.
     * - Returns: an array of series APIs for all series created through this chart that belong to this pane
     */
    func getSeries() async throws(JavaScriptBridgeError) -> [any SeriesApi]
}

/**
 The main interface of a single chart
 */
@MainActor
public protocol ChartApi: AnyObject {
    // Async methods throw `JavaScriptBridgeError` when the bridge context is unavailable,
    // the JavaScript evaluation fails, the result shape is invalid, decoding fails, or
    // the caller cancels the operation.

    /**
     * Subsription delegate for chart events. Weak reference.
     */
    var delegate: ChartDelegate? { get set }

    /// Async event streams. Creating a stream automatically manages the corresponding
    /// JavaScript subscription for that consumer's lifetime.
    var clickEvents: AsyncStream<MouseEventParams> { get }
    var doubleClickEvents: AsyncStream<MouseEventParams> { get }
    var crosshairMoveEvents: AsyncStream<MouseEventParams> { get }

    /**
     * Removes the chart object including all DOM elements.
     * This is an irreversible operation, you cannot do anything with the chart after removing it.
     */
    func remove()

    /**
     * Sets fixed size of the chart. By default chart takes up 100% of its container
     * - Parameter height: target height of the chart
     * - Parameter width: target width of the chart
     * - Parameter forceRepaint: true to initiate resize immediately.
     * One could need this to get screenshot immediately after resize
     */
    func resize(width: Double, height: Double, forceRepaint: Bool?)

    // MARK: - Series methods

    /**
     * Creates an area series with specified parameters
     * - Parameter options: customization parameters of the series being created
     * - Returns: an interface of the created series
     */
    func addAreaSeries(options: AreaSeries.Options?) -> AreaSeries

    /**
     * Creates a bar series with specified parameters
     * - Parameter options: customization parameters of the series being created
     * - Returns: an interface of the created series
     */
    func addBarSeries(options: BarSeries.Options?) -> BarSeries

    /**
     * Creates a candlestick series with specified parameters
     * - Parameter options: customization parameters of the series being created
     * - Returns: an interface of the created series
     */
    func addCandlestickSeries(options: CandlestickSeries.Options?) -> CandlestickSeries

    /**
     * Creates a rounded candlestick custom series with specified parameters
     * - Parameter options: customization parameters of the series being created
     * - Returns: an interface of the created series
     */
    func addRoundedCandlestickSeries(options: RoundedCandlestickSeries.Options?) -> RoundedCandlestickSeries

    /**
     * Creates a rounded histogram custom series with specified parameters
     * - Parameter options: customization parameters of the series being created
     * - Returns: an interface of the created series
     */
    func addRoundedHistogramSeries(options: RoundedHistogramSeries.Options?) -> RoundedHistogramSeries

    /**
     * Creates a histogram series with specified parameters
     * - Parameter options: customization parameters of the series being created
     * - Returns: an interface of the created series
     */
    func addHistogramSeries(options: HistogramSeries.Options?) -> HistogramSeries

    /**
     * Creates a line series with specified parameters
     * - Parameter options: customization parameters of the series being created
     * - Returns: an interface of the created series
     */
    func addLineSeries(options: LineSeries.Options?) -> LineSeries

    /**
     * Creates a baseline series with specified parameters.
     * - Parameter options: customization parameters of the series being created
     * - Returns: an interface of the created series
     */
    func addBaselineSeries(options: BaselineSeries.Options?) -> BaselineSeries

    // MARK: - Series methods with pane index (v5 multi-pane support)

    /**
     * Creates an area series on the specified pane
     * - Parameter options: customization parameters of the series being created
     * - Parameter paneIndex: Index of the pane to attach the series to
     * - Returns: an interface of the created series
     */
    func addAreaSeries(options: AreaSeries.Options?, paneIndex: Int) -> AreaSeries

    /**
     * Creates a bar series on the specified pane
     * - Parameter options: customization parameters of the series being created
     * - Parameter paneIndex: Index of the pane to attach the series to
     * - Returns: an interface of the created series
     */
    func addBarSeries(options: BarSeries.Options?, paneIndex: Int) -> BarSeries

    /**
     * Creates a candlestick series on the specified pane
     * - Parameter options: customization parameters of the series being created
     * - Parameter paneIndex: Index of the pane to attach the series to
     * - Returns: an interface of the created series
     */
    func addCandlestickSeries(options: CandlestickSeries.Options?, paneIndex: Int) -> CandlestickSeries

    /**
     * Creates a rounded candlestick custom series on the specified pane
     * - Parameter options: customization parameters of the series being created
     * - Parameter paneIndex: Index of the pane to attach the series to
     * - Returns: an interface of the created series
     */
    func addRoundedCandlestickSeries(
        options: RoundedCandlestickSeries.Options?,
        paneIndex: Int
    ) -> RoundedCandlestickSeries

    /**
     * Creates a rounded histogram custom series on the specified pane
     * - Parameter options: customization parameters of the series being created
     * - Parameter paneIndex: Index of the pane to attach the series to
     * - Returns: an interface of the created series
     */
    func addRoundedHistogramSeries(
        options: RoundedHistogramSeries.Options?,
        paneIndex: Int
    ) -> RoundedHistogramSeries

    /**
     * Creates a histogram series on the specified pane
     * - Parameter options: customization parameters of the series being created
     * - Parameter paneIndex: Index of the pane to attach the series to
     * - Returns: an interface of the created series
     */
    func addHistogramSeries(options: HistogramSeries.Options?, paneIndex: Int) -> HistogramSeries

    /**
     * Creates a line series on the specified pane
     * - Parameter options: customization parameters of the series being created
     * - Parameter paneIndex: Index of the pane to attach the series to
     * - Returns: an interface of the created series
     */
    func addLineSeries(options: LineSeries.Options?, paneIndex: Int) -> LineSeries

    /**
     * Creates a baseline series on the specified pane
     * - Parameter options: customization parameters of the series being created
     * - Parameter paneIndex: Index of the pane to attach the series to
     * - Returns: an interface of the created series
     */
    func addBaselineSeries(options: BaselineSeries.Options?, paneIndex: Int) -> BaselineSeries

    // MARK: - Pane management (v5)

    /**
     * Adds a new pane to the chart.
     */
    @discardableResult
    func addPane(preserveEmptyPane: Bool?) async throws(JavaScriptBridgeError) -> PaneApi

    /**
     * Removes pane at a given index.
     */
    func removePane(index: Int) async throws(JavaScriptBridgeError)

    /**
     * Swaps positions of two panes.
     */
    func swapPanes(first: Int, second: Int) async throws(JavaScriptBridgeError)

    /**
     * Removes a series of any type.
     * This is an irreversible operation, you cannot do anything with the series after removing it
     * - Parameter seriesApi: Series to remove
     */
    func removeSeries<T: SeriesApi & SeriesObject>(seriesApi: T)

    // MARK: - Subsriptions methods

    /**
     * Adds a subscription to mouse click event
     * - Parameter handler: handler (function) to be called on mouse click
     */
    func subscribeClick()

    /**
     * Removes mouse click subscription
     * - Parameter handler: previously subscribed handler
     */
    func unsubscribeClick()

    /**
     * Adds a subscription to mouse double-click event
     */
    func subscribeDblClick()

    /**
     * Removes mouse double-click subscription
     */
    func unsubscribeDblClick()

    /**
     * Adds a subscription to crosshair movement to receive notifications on crosshair movements
     * - Parameter handler: handler (function) to be called on crosshair move
     */
    func subscribeCrosshairMove()

    /**
     * Removes a subscription on crosshair movement
     * - Parameter handler: previously subscribed handler
     */
    func unsubscribeCrosshairMove()

    /**
     * Sets crosshair position programmatically.
     */
    func setCrosshairPosition<T: SeriesApi & SeriesObject>(price: Double, horizontalPosition: Time, seriesApi: T) async throws(JavaScriptBridgeError)

    /**
     * Clears crosshair position previously set programmatically.
     */
    func clearCrosshairPosition()

    // MARK: - Other APIs and options methods

    /**
     * Returns API to manipulate the price scale
     * - Parameter priceScaleID: id of scale to access to. `nil` resolves to the default right price scale.
     * - Returns: target API
     */
    func priceScale(priceScaleId: String?, paneIndex: Int?) -> PriceScaleApi

    /**
     * Returns API to manipulate the time scale
     * - Returns: target API
     */
    func timeScale() -> TimeScaleApi

    /**
     * Applies new options to the chart
     * - Parameter options: any subset of chart options
     */
    func applyOptions(options: ChartOptions)

    // MARK: - Watermark plugin methods

    /**
     * Creates a text watermark primitive on the specified pane.
     * - Parameter paneIndex: Index of the pane to attach the watermark to (default: 0 for the main pane).
     * - Parameter options: Watermark options including text, color, alignment, and font settings.
     * - Returns: A handle to the created text watermark for further operations (update/detach).
     */
    func createTextWatermark(paneIndex: Int, options: TextWatermarkOptions) -> TextWatermark

    /**
     * Creates an image watermark primitive on the specified pane.
     * - Parameter paneIndex: Index of the pane to attach the watermark to (default: 0 for the main pane).
     * - Parameter imageUrl: URL of the image to use as a watermark.
     * - Parameter options: Watermark options including alpha, padding, and size constraints.
     * - Returns: A handle to the created image watermark for further operations (update/detach).
     */
    func createImageWatermark(paneIndex: Int, imageUrl: String, options: ImageWatermarkOptions) -> ImageWatermark

    // MARK: - Async methods (Swift 6)

    /**
     * Returns all pane APIs currently attached to the chart.
     * - Returns: array of pane APIs
     */
    func panes() async throws(JavaScriptBridgeError) -> [PaneApi]

    /**
     * Returns pane size for the specified pane index.
     * - Parameter paneIndex: the index of the pane
     * - Returns: the pane size as a Rectangle
     */
    func paneSize(paneIndex: Int) async throws(JavaScriptBridgeError) -> Rectangle

    /**
     * Returns currently applied options
     * - Returns: full set of currently applied options, including defaults
     */
    func options() async throws(JavaScriptBridgeError) -> ChartOptions

    /**
     * Returns whether auto-size is currently active for the chart.
     * - Returns: true when auto-size is active
     */
    func autoSizeActive() async throws(JavaScriptBridgeError) -> Bool

    /**
     * Make a screenshot of the chart with optional rendering flags.
     * - Parameters:
     *   - addTopLayer: whether to add the top layer
     *   - includeCrosshair: whether to include the crosshair
     * - Returns: a UIImage with the chart drawn on it
     */
    func takeScreenshot(addTopLayer: Bool?, includeCrosshair: Bool?) async throws(JavaScriptBridgeError) -> UIImage
}

// MARK: -

public extension ChartApi {
    func addPane() async throws(JavaScriptBridgeError) -> PaneApi {
        try await addPane(preserveEmptyPane: nil)
    }

    func priceScale(priceScaleId: String?) -> PriceScaleApi {
        priceScale(priceScaleId: priceScaleId, paneIndex: nil)
    }

    /**
     * Make a screenshot of the chart with all the elements excluding crosshair.
     * - Returns: a UIImage with the chart drawn on it
     */
    func takeScreenshot() async throws(JavaScriptBridgeError) -> UIImage {
        try await takeScreenshot(addTopLayer: nil, includeCrosshair: nil)
    }

    /**
     * Sets fixed size of the chart. By default chart takes up 100% of its container
     * - Parameter height: target height of the chart
     * - Parameter width: target width of the chart
     * - Parameter forceRepaint: true to initiate resize immediately.
     * One could need this to get screenshot immediately after resize
     */
    func resize(width: CGFloat, height: CGFloat, forceRepaint: Bool?) {
        self.resize(width: Double(width), height: Double(height), forceRepaint: forceRepaint)
    }

    /**
     * Sets fixed size of the chart. By default chart takes up 100% of its container
     * - Parameter height: target height of the chart
     * - Parameter width: target width of the chart
     * - Parameter forceRepaint: true to initiate resize immediately.
     * One could need this to get screenshot immediately after resize
     */
    func resize(width: Int, height: Int, forceRepaint: Bool?) {
        self.resize(width: Double(width), height: Double(height), forceRepaint: forceRepaint)
    }
}

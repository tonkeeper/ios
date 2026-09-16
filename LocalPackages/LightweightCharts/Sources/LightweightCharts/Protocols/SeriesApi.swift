import Foundation

public enum DataChangedScope: String, Codable, Sendable {
    case full
    case update
}

@MainActor
public protocol SeriesDelegate: AnyObject {
    func didDataChange(onSeries series: any SeriesApi, scope: DataChangedScope)
}

@MainActor
public protocol SeriesApi: AnyObject {
    // Async methods throw `JavaScriptBridgeError` when the bridge context is unavailable,
    // the JavaScript evaluation fails, the result shape is invalid, decoding fails, or
    // the caller cancels the operation.

    var delegate: SeriesDelegate? { get set }

    var dataChangedEvents: AsyncStream<DataChangedScope> { get }

    associatedtype Options: SeriesOptionsCommon
    associatedtype TickValue: SeriesData

    // MARK: - Synchronous methods

    /**
     * Returns current price formatter
     * - Returns: interface to the price formatter object that can be used to format prices in the same way as the chart does
     */
    func priceFormatter() -> PriceFormatterApi

    /**
     * Applies new options to the existing series
     * - Parameter options: any subset of options
     */
    func applyOptions(options: Options)

    /**
     * Returns interface of the price scale the series is currently attached
     * - Returns: object to control the price scale
     */
    func priceScale() -> PriceScaleApi

    /**
     * Sets or replaces series data
     * - Parameter data: ordered (earlier time point goes first) array of data items.
     * Old data is fully replaced with the new one.
     */
    func setData(data: [TickValue])

    /**
     * Adds or replaces a new bar
     * - Parameter bar: a single data item to be added.
     * Time of the new item must be greater or equal to the latest existing time point.
     * If the new item's time is equal to the last existing item's time, then the existing item is replaced with the new one.
     */
    func update(bar: TickValue, historicalUpdate: Bool?)

    /**
     * Sets or replaces series data
     * - Parameter data: ordered (earlier time point goes first) array of data items.
     * Old data is fully replaced with the new one.
     */
    func setData(data: [WhitespaceData])

    /**
     * Adds or replaces a new bar
     * - Parameter bar: a single data item to be added.
     * Time of the new item must be greater or equal to the latest existing time point.
     * If the new item's time is equal to the last existing item's time, then the existing item is replaced with the new one.
     */
    func update(bar: WhitespaceData, historicalUpdate: Bool?)

    /**
     * Sets or replaces series data
     * - Parameter data: ordered (earlier time point goes first) array of data items.
     * Old data is fully replaced with the new one.
     */
    func setData(data: [SeriesDataType<TickValue>])

    /**
     * Adds or replaces a new bar
     * - Parameter bar: a single data item to be added.
     * Time of the new item must be greater or equal to the latest existing time point.
     * If the new item's time is equal to the last existing item's time, then the existing item is replaced with the new one.
     */
    func update(bar: SeriesDataType<TickValue>, historicalUpdate: Bool?)

    /**
     * Sets markers for the series
     * - Parameter data: array of series markers.
     * This array should be sorted by time.
     * Several markers with same time are allowed.
     */
    func setMarkers(data: [SeriesMarker])

    /**
     * Creates a new price line
     * - Parameter options:  any subset of options
     */
    func createPriceLine(options: PriceLineOptions?) -> PriceLine

    /**
     * Removes an existing price line
     * - Parameter line: line to remove
     */
    func removePriceLine(line: PriceLine)

    /**
     * Sets the rendering order of this series within its pane.
     * - Parameter order: the new order value
     */
    func setSeriesOrder(order: Int)

    /**
     * Moves this series to the specified pane.
     * - Parameter paneIndex: the target pane index
     */
    func moveToPane(paneIndex: Int) async throws(JavaScriptBridgeError)

    func subscribeDataChanged()

    func unsubscribeDataChanged()

    // MARK: - Async methods (Swift 6)

    /**
     * Converts specified series price to pixel coordinate according to the chart price scale
     * - Parameter price: input price to be converted
     * - Returns: pixel coordinate of the price level on the chart
     */
    func priceToCoordinate(price: Double) async throws(JavaScriptBridgeError) -> Coordinate?

    /**
     * Converts specified coordinate to price value according to the series price scale
     * - Parameter coordinate: input coordinate to be converted
     * - Returns: price value of the coordinate on the chart
     */
    func coordinateToPrice(coordinate: Double) async throws(JavaScriptBridgeError) -> BarPrice?

    /**
     * Retrieves information about the series' data within a given logical range.
     *
     * - Parameter range: the logical range to retrieve info for, or `nil` to mirror the JS `null` input case
     * - Returns: the bars info for the given logical range, or `nil` when the JS API reports no bars for the range: fields `from` and `to` are
     * `Logical` values for the first and last bar within the range, and `barsBefore` and
     * `barsAfter` count the available bars outside the given index range. If these
     * values are negative, it means that the given range is not fully filled with bars
     * on the given side, but bars are missing instead (would show up as a margin if the
     * the given index range falls into the viewport).
     */
    func barsInLogicalRange(range: FromToRange<Double>?) async throws(JavaScriptBridgeError) -> BarsInfo?

    /**
     * Returns currently applied options
     * - Returns: full set of currently applied options, including defaults
     */
    func options() async throws(JavaScriptBridgeError) -> Options

    func data() async throws(JavaScriptBridgeError) -> [TickValue]

    /**
     * Returns a bar data by provided logical index.
     * - Parameters:
     *   - logicalIndex: the logical index of the bar
     *   - mismatchDirection: the direction to use for mismatched data
     * - Returns: the bar data at the specified index
     */
    func dataByIndex(logicalIndex: Int, mismatchDirection: MismatchDirection?) async throws(JavaScriptBridgeError) -> TickValue?

    /**
     * Returns a list of series markers.
     * - Returns: list of series markers
     */
    func markers() async throws(JavaScriptBridgeError) -> [SeriesMarker]

    /**
     * Returns all currently attached price lines for this series.
     * - Returns: array of price lines
     */
    func priceLines() async throws(JavaScriptBridgeError) -> [PriceLine]

    /**
     * Returns the type of this series
     * - Returns: the SeriesType
     */
    func seriesType() async throws(JavaScriptBridgeError) -> SeriesType

    /**
     * Returns the current rendering order of this series within its pane.
     * - Returns: the series order value
     */
    func seriesOrder() async throws(JavaScriptBridgeError) -> Int

    /**
     * Removes data points from the end of the series.
     * - Parameter count: number of data points to remove
     * - Returns: the removed data points
     */
    func pop(count: Int) async throws(JavaScriptBridgeError) -> [TickValue]

    /**
     * Retrieves last value data including price and color.
     * - Parameter globalLast: if true, returns the last value across all series
     * - Returns: the last value data result
     */
    func lastValueData(globalLast: Bool) async throws(JavaScriptBridgeError) -> LastValueDataResult

    func getPane() async throws(JavaScriptBridgeError) -> PaneApi
}

public extension SeriesDelegate {
    func didDataChange(onSeries series: any SeriesApi, scope: DataChangedScope) {}
}

public extension SeriesApi {
    func update(bar: TickValue) {
        update(bar: bar, historicalUpdate: nil)
    }

    func update(bar: WhitespaceData) {
        update(bar: bar, historicalUpdate: nil)
    }

    func update(bar: SeriesDataType<TickValue>) {
        update(bar: bar, historicalUpdate: nil)
    }
}

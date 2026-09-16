import CoreGraphics

/** Interface to chart time scale */
@MainActor
public protocol TimeScaleApi: AnyObject {
    // Async methods throw `JavaScriptBridgeError` when the bridge context is unavailable,
    // the JavaScript evaluation fails, the result shape is invalid, decoding fails, or
    // the caller cancels the operation.

    var delegate: TimeScaleDelegate? { get set }

    // MARK: - Synchronous methods

    /**
     * Scrolls the chart to the specified position
     * - Parameter position: target data position
     * - Parameter animated: setting this to true makes the chart scrolling smooth and adds animation
     */
    func scrollToPosition(position: Double, animated: Bool)

    /**
     * Restores default scroll position of the chart. This process is always animated.
     */
    func scrollToRealTime()

    /**
     * Sets visible range of data
     * - Parameter range: target visible range of data
     */
    func setVisibleRange(range: TimeRange)

    /**
     * Sets visible logical range of data.
     * - Parameter range: target visible logical range of data.
     */
    func setVisibleLogicalRange(range: FromToRange<Double>)

    /**
     * Restores default zooming and scroll position of the time scale
     */
    func resetTimeScale()

    /**
     * Automatically calculates the visible range to fit all data from all series
     * This is a momentary operation.
     */
    func fitContent()

    /**
     * Adds a subscription to visible range changes to receive notification about visible range of data changes
     */
    func subscribeVisibleTimeRangeChange()

    /**
     * Removes a subscription to visible range changes
     */
    func unsubscribeVisibleTimeRangeChange()

    /**
     * Adds a subscription to visible index range changes to receive notifications about visible indexes of the data
     */
    func subscribeVisibleLogicalRangeChange()

    /**
     * Removes a subscription to visible index range changes
     */
    func unsubscribeVisibleLogicalRangeChange()

    func subscribeSizeChange()

    func unsubscribeSizeChange()

    /**
     * Applies new options to the time scale.
     * - Parameter options: any subset of options
     */
    func applyOptions(options: TimeScaleOptions)

    // MARK: - Async methods (Swift 6)

    /**
     * Returns current scroll position of the chart
     * - Returns: a distance from the right edge to the latest bar, measured in bars
     */
    func scrollPosition() async throws(JavaScriptBridgeError) -> Double

    /**
     * Returns current visible time range of the chart
     * - Returns: visible range or null if the chart has no data at all
     */
    func getVisibleRange() async throws(JavaScriptBridgeError) -> TimeRange?

    /**
     * Returns the currently visible logical range of data.
     * - Returns: visible range or null if the chart has no data at all
     */
    func getVisibleLogicalRange() async throws(JavaScriptBridgeError) -> LogicalRange?

    /**
     * Converts a logical index to local x coordinate.
     * - Parameter logical: logical index needs to be converted
     * - Returns: x coordinate of that time or `null` if the chart doesn't have data
     */
    func logicalToCoordinate(logical: Logical) async throws(JavaScriptBridgeError) -> Coordinate?

    /**
     * Converts a coordinate to logical index.
     * - Parameter x: coordinate needs to be converted
     * - Returns: logical index that is located on that coordinate or `null` if the chart doesn't have data
     */
    func coordinateToLogical(x: Double) async throws(JavaScriptBridgeError) -> Logical?

    /**
     * Converts a time to local x coordinate.
     * - Parameter time: time needs to be converted
     * - Returns: x coordinate of that time or `null` if no time found on time scale
     */
    func timeToCoordinate(time: Time) async throws(JavaScriptBridgeError) -> Coordinate?

    /**
     * Converts a time to a logical index on the time scale.
     * - Parameter time: time to convert
     * - Parameter findNearest: whether nearest match should be returned when exact time is absent
     * - Returns: logical index or nil when no matching time exists
     */
    func timeToIndex(time: Time, findNearest: Bool) async throws(JavaScriptBridgeError) -> Int?

    /**
     * Converts a coordinate to time.
     * - Parameter x: coordinate needs to be converted
     * - Returns: time of a bar that is located on that coordinate or `null` if there are no bars found on that coordinate
     */
    func coordinateToTime(x: Double) async throws(JavaScriptBridgeError) -> Time?

    /**
     * Returns the width of the time scale.
     * - Returns: width in pixels
     */
    func width() async throws(JavaScriptBridgeError) -> Double

    /**
     * Returns the height of the time scale.
     * - Returns: height in pixels
     */
    func height() async throws(JavaScriptBridgeError) -> Double

    /**
     * Returns current options
     * - Returns: currently applied options
     */
    func options() async throws(JavaScriptBridgeError) -> TimeScaleOptions
}

// MARK: -

extension TimeScaleApi {
    /**
     * Scrolls the chart to the specified position
     * - Parameter position: target data position
     * - Parameter animated: setting this to true makes the chart scrolling smooth and adds animation
     */
    func scrollToPosition(position: CGFloat, animated: Bool) {
        self.scrollToPosition(position: Double(position), animated: animated)
    }

    func timeToIndex(time: Time) async throws(JavaScriptBridgeError) -> Int? {
        try await timeToIndex(time: time, findNearest: false)
    }
}

import Foundation

/** Interface to control chart's price scale */
@MainActor
public protocol PriceScaleApi: AnyObject {
    // Async methods throw `JavaScriptBridgeError` when the bridge context is unavailable,
    // the JavaScript evaluation fails, the result shape is invalid, decoding fails, or
    // the caller cancels the operation.

    // MARK: - Synchronous methods

    /**
     * Applies new options to the price scale
     * - Parameter options: any subset of PriceScaleOptions
     */
    func applyOptions(options: PriceScaleOptions)

    /**
     * Sets the visible price range on this price scale.
     * - Parameter from: the lower bound of the price range
     * - Parameter to: the upper bound of the price range
     */
    func setVisibleRange(from: Double, to: Double)

    /**
     * Enables or disables auto-scaling on this price scale.
     * - Parameter on: true to enable auto-scale, false to disable
     */
    func setAutoScale(on: Bool)

    // MARK: - Async methods (Swift 6)

    /**
     * Returns currently applied options of the price scale
     * - Returns: full set of currently applied options, including defaults
     */
    func options() async throws(JavaScriptBridgeError) -> PriceScaleOptions

    /**
     * Returns a width of the price scale if it's visible or 0 if invisible.
     * - Returns: a width of the price scale if it's visible or 0 if invisible
     */
    func width() async throws(JavaScriptBridgeError) -> Double

    /**
     * Returns the current visible price range on this price scale.
     * - Returns: the visible range, or nil if not available
     */
    func getVisibleRange() async throws(JavaScriptBridgeError) -> FromToRange<Double>?
}

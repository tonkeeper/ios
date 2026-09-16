import Foundation

/** Interface to be implemented by the object in order to be used as a price formatter */
@MainActor
public protocol PriceFormatterApi: AnyObject {
    // Async methods throw `JavaScriptBridgeError` when the bridge context is unavailable,
    // the JavaScript evaluation fails, the result shape is invalid, decoding fails, or
    // the caller cancels the operation.

    // MARK: - Async methods (Swift 6)

    /**
     * Formatting function
     * - Parameter price: original price to be formatted
     * - Returns: formatted price
     */
    func format(price: BarPrice) async throws(JavaScriptBridgeError) -> String

    /**
     * Formats tickmark values using the formatter's tickmark-specific behavior.
     * - Parameter prices: original prices to be formatted
     * - Returns: formatted tickmark labels
     */
    func formatTickmarks(prices: [BarPrice]) async throws(JavaScriptBridgeError) -> [String]
}

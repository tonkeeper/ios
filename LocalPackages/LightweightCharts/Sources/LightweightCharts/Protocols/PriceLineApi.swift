import Foundation

@MainActor
public protocol PriceLineApi: AnyObject {
    // Async methods throw `JavaScriptBridgeError` when the bridge context is unavailable,
    // the JavaScript evaluation fails, the result shape is invalid, decoding fails, or
    // the caller cancels the operation.

    // MARK: - Async methods (Swift 6)

    /// Returns currently applied options
    /// - Returns: full set of currently applied options
    func options() async throws(JavaScriptBridgeError) -> PriceLineOptions

    // MARK: - Synchronous methods

    /// Applies new options to the price line
    /// - Parameter options: any subset of options
    func applyOptions(options: PriceLineOptions)
}

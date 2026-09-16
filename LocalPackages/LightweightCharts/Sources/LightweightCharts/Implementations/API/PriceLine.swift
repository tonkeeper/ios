import Foundation

@MainActor
public class PriceLine: JavaScriptObject {
    public let jsName = "priceLine" + .uniqueString
    weak var context: JavaScriptEvaluator?

    init(context: JavaScriptEvaluator?) {
        self.context = context
    }

    private func requireContext() throws(JavaScriptBridgeError) -> JavaScriptEvaluator {
        guard let context = context else {
            throw JavaScriptBridgeError.contextUnavailable
        }
        return context
    }
}

// MARK: - PriceLineApi

extension PriceLine: PriceLineApi {
    // MARK: - Async methods (Swift 6)

    public func options() async throws(JavaScriptBridgeError) -> PriceLineOptions {
        let script = "\(jsName).options();"
        return try await requireContext().decodedResult(forScript: script)
    }

    // MARK: - Synchronous methods

    public func applyOptions(options: PriceLineOptions) {
        let script = "\(jsName).applyOptions(\(options.jsonString));"
        context?.submitScript(script)
    }
}

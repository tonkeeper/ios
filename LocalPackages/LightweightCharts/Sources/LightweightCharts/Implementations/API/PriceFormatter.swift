import Foundation

@MainActor
class PriceFormatter: JavaScriptObject {
    let jsName = "priceFormatter" + .uniqueString

    private weak var context: JavaScriptEvaluator?

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

// MARK: - PriceFormatterApi

extension PriceFormatter: PriceFormatterApi {
    // MARK: - Async methods (Swift 6)

    func format(price: BarPrice) async throws(JavaScriptBridgeError) -> String {
        let script = "\(jsName).format(\(price.jsonString));"
        return try await requireContext().evaluate(script: script, resultType: String.self)
    }

    func formatTickmarks(prices: [BarPrice]) async throws(JavaScriptBridgeError) -> [String] {
        let script = "\(jsName).formatTickmarks(\(prices.jsonString));"
        return try await requireContext().decodedResult(forScript: script)
    }
}

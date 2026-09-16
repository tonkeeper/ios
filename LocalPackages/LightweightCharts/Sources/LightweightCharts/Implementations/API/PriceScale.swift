import Foundation

@MainActor
class PriceScale: JavaScriptObject {
    let jsName = "priceScale" + .uniqueString

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

// MARK: - PriceScaleApi

extension PriceScale: PriceScaleApi {
    // MARK: - Async methods (Swift 6)

    func options() async throws(JavaScriptBridgeError) -> PriceScaleOptions {
        let script = "\(jsName).options();"
        return try await requireContext().decodedResult(forScript: script)
    }

    func width() async throws(JavaScriptBridgeError) -> Double {
        let script = "\(jsName).width();"
        return try await requireContext().evaluate(script: script, resultType: Double.self)
    }

    func getVisibleRange() async throws(JavaScriptBridgeError) -> FromToRange<Double>? {
        let script = "\(jsName).getVisibleRange();"
        return try await requireContext().decodedResult(forScript: script)
    }

    // MARK: - Synchronous methods

    func applyOptions(options: PriceScaleOptions) {
        let script = "\(jsName).applyOptions(\(options.jsonString));"
        context?.submitScript(script)
    }

    func setVisibleRange(from: Double, to: Double) {
        let range = FromToRange(from: from, to: to)
        let script = "\(jsName).setVisibleRange(\(range.jsonString));"
        context?.submitScript(script)
    }

    func setAutoScale(on: Bool) {
        let script = "\(jsName).setAutoScale(\(on ? "true" : "false"));"
        context?.submitScript(script)
    }
}

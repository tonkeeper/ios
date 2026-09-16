import Foundation

@MainActor
open class SeriesPluginAdapter<Series: SeriesApi & SeriesObject>: SeriesPlugin {
    public weak var series: Series?

    public let jsName: String

    private weak var context: JavaScriptEvaluator?

    public private(set) var isDetached: Bool = false

    public init(series: Series) {
        self.series = series
        self.context = series.context
        self.jsName = SeriesPluginAdapter.makeJSName(for: type(of: series))
    }

    public func detach() {
        isDetached = true
        series = nil
    }

    func evaluateScript(_ script: String) {
        guard let context = context else { return }
        context.submitScript(script)
    }

    func requireContext() throws(JavaScriptBridgeError) -> JavaScriptEvaluator {
        guard let context else {
            throw JavaScriptBridgeError.contextUnavailable
        }
        return context
    }

    func evaluate<T: Decodable>(
        script: String,
        resultType: T.Type,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        guard let context = context else {
            completion(.failure(JavaScriptBridgeError.contextUnavailable))
            return
        }

        if let callbackContext = context as? JavaScriptCallbackEvaluator {
            callbackContext.evaluate(script: script, resultType: resultType, completion: completion)
            return
        }

        completion(.failure(JavaScriptBridgeError.contextUnavailable))
    }

    func decodedResult<T: Decodable>(
        forScript script: String,
        completion: @escaping (T?) -> Void
    ) {
        guard let context = context else {
            completion(nil)
            return
        }

        guard let callbackContext = context as? JavaScriptCallbackEvaluator else {
            completion(nil)
            return
        }

        callbackContext.decodedResult(forScript: script) { (result: Result<T, Error>) in
            switch result {
            case let .success(value):
                completion(value)
            case .failure:
                completion(nil)
            }
        }
    }

    // MARK: - Private Methods

    /// Generates a unique JavaScript variable name for a plugin instance.
    ///
    /// - Parameter seriesType: The type of the series the plugin is attached to.
    /// - Returns: A unique JavaScript variable name.
    private static func makeJSName(for seriesType: Any.Type) -> String {
        let seriesName = String(describing: seriesType)
        return "plugin_\(seriesName)_\(String.uniqueString)"
    }
}

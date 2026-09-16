import WebKit

@MainActor
public protocol JavaScriptErrorDelegate: AnyObject {
    func didFailEvaluateScript(_ script: String, withError error: Error)
}

// MARK: -

class WebView: WKWebView {
    weak var errorDelegate: JavaScriptErrorDelegate?
}

// MARK: - JavaScriptEvaluator

extension WebView: JavaScriptEvaluator {
    private static func resultDescription(_ value: Any?) -> String {
        guard let value else {
            return "nil"
        }
        return String(describing: type(of: value))
    }

    private func decodeJSONResult<T: Decodable>(_ result: Any?, as type: T.Type) throws(JavaScriptBridgeError) -> T {
        guard let jsonString = result as? String else {
            throw JavaScriptBridgeError.invalidResult(
                expected: "JSON string for \(String(describing: type))",
                actual: Self.resultDescription(result)
            )
        }

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw JavaScriptBridgeError.invalidResult(
                expected: "UTF-8 JSON data for \(String(describing: type))",
                actual: "non-UTF8 string"
            )
        }

        do {
            return try JSONDecoder().decode(T.self, from: jsonData)
        } catch {
            throw JavaScriptBridgeError.decodingFailed(type: String(describing: type), message: error.localizedDescription)
        }
    }

    func submitScript(_ script: String) {
        evaluateJavaScript(script) { [weak self] _, error in
            if let error = error {
                let bridgeError = JavaScriptBridgeError.wrap(error, script: script)
                self?.errorDelegate?.didFailEvaluateScript(script, withError: bridgeError)
            }
        }
    }

    // MARK: - Async methods (Swift 6)

    /// Evaluates JavaScript code and returns the result asynchronously
    /// - Parameter script: The JavaScript code to evaluate
    /// - Returns: The result of the evaluation, if any
    func evaluateScript(_ script: String) async throws(JavaScriptBridgeError) -> Any? {
        try JavaScriptBridgeError.checkCancellation()
        do {
            let result = try await evaluateJavaScript(script, contentWorld: .page)
            try JavaScriptBridgeError.checkCancellation()
            return result
        } catch {
            let bridgeError = JavaScriptBridgeError.wrap(error, script: script)
            if case .cancelled = bridgeError {
                throw bridgeError
            }
            errorDelegate?.didFailEvaluateScript(script, withError: bridgeError)
            throw bridgeError
        }
    }

    /// Evaluates JavaScript code and decodes the result as a specified type
    /// - Parameters:
    ///   - script: The JavaScript code to evaluate
    ///   - resultType: The type to decode the result as
    /// - Returns: The decoded result
    func evaluate<T: Decodable>(script: String, resultType: T.Type) async throws(JavaScriptBridgeError) -> T {
        try JavaScriptBridgeError.checkCancellation()
        let jsonStringifiedScript = "var scriptResult = \(script); JSON.stringify(scriptResult);"
        let result = try await evaluateScript(jsonStringifiedScript)
        try JavaScriptBridgeError.checkCancellation()
        return try decodeJSONResult(result, as: T.self)
    }

    /// Evaluates JavaScript code and decodes the result
    /// - Parameter script: The JavaScript code to evaluate
    /// - Returns: The decoded result
    func decodedResult<T: Decodable>(forScript script: String) async throws(JavaScriptBridgeError) -> T {
        try JavaScriptBridgeError.checkCancellation()
        return try await evaluate(script: script, resultType: T.self)
    }
}

// MARK: - JavaScriptCallbackEvaluator

extension WebView: JavaScriptCallbackEvaluator {
    func evaluate<T: Decodable>(
        script: String,
        resultType: T.Type,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        let jsonStringifiedScript = "var scriptResult = \(script); JSON.stringify(scriptResult);"
        evaluateJavaScript(jsonStringifiedScript) { [weak self] result, error in
            if let error {
                let bridgeError = JavaScriptBridgeError.wrap(error, script: script)
                self?.errorDelegate?.didFailEvaluateScript(script, withError: bridgeError)
                completion(.failure(bridgeError))
                return
            }

            do {
                let value = try self?.decodeJSONResult(result, as: T.self)
                if let value {
                    completion(.success(value))
                } else {
                    completion(.failure(JavaScriptBridgeError.contextUnavailable))
                }
            } catch {
                completion(.failure(error))
            }
        }
    }

    func decodedResult<T: Decodable>(
        forScript script: String,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        evaluate(script: script, resultType: T.self, completion: completion)
    }
}

// MARK: - JavaScriptMessageProducer

extension WebView: JavaScriptMessageProducer {
    func addMessageHandler(_ messageHandler: WKScriptMessageHandler, name: String) {
        configuration.userContentController.add(messageHandler, name: name)
    }
}

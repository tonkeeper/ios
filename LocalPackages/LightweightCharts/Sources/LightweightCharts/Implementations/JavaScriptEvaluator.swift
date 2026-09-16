import Foundation
import WebKit

public enum JavaScriptBridgeError: Error, Sendable {
    case contextUnavailable
    case cancelled
    case evaluationFailed(script: String, message: String)
    case invalidResult(expected: String, actual: String)
    case decodingFailed(type: String, message: String)
}

extension JavaScriptBridgeError: LocalizedError {
    static func wrap(_ error: Error, script: String? = nil) -> JavaScriptBridgeError {
        if let bridgeError = error as? JavaScriptBridgeError {
            return bridgeError
        }
        if error is CancellationError {
            return .cancelled
        }
        return .evaluationFailed(script: script ?? "<unknown>", message: error.localizedDescription)
    }

    static func checkCancellation() throws(JavaScriptBridgeError) {
        if Task.isCancelled {
            throw .cancelled
        }
    }

    public var errorDescription: String? {
        switch self {
        case .contextUnavailable:
            return "The JavaScript bridge context is unavailable."
        case .cancelled:
            return "The JavaScript bridge operation was cancelled."
        case let .evaluationFailed(script, message):
            return "JavaScript evaluation failed for `\(script)`: \(message)"
        case let .invalidResult(expected, actual):
            return "Invalid JavaScript result. Expected \(expected), got \(actual)."
        case let .decodingFailed(type, message):
            return "Failed to decode JavaScript result as \(type): \(message)"
        }
    }
}

@MainActor
public protocol JavaScriptEvaluator: AnyObject {
    // MARK: - Fire-and-forget methods

    /// Submits JavaScript code without waiting for a result.
    /// - Parameter script: The JavaScript code to evaluate
    func submitScript(_ script: String)

    // MARK: - Async methods (Swift 6)

    /// Evaluates JavaScript code and returns the result asynchronously
    /// - Parameter script: The JavaScript code to evaluate
    /// - Returns: The result of the evaluation, if any
    func evaluateScript(_ script: String) async throws(JavaScriptBridgeError) -> Any?

    /// Evaluates JavaScript code and decodes the result as a specified type
    /// - Parameter script: The JavaScript code to evaluate
    /// - Parameter resultType: The type to decode the result as
    /// - Returns: The decoded result
    func evaluate<T: Decodable>(script: String, resultType: T.Type) async throws(JavaScriptBridgeError) -> T

    /// Evaluates JavaScript code and decodes the result
    /// - Parameter script: The JavaScript code to evaluate
    /// - Returns: The decoded result
    func decodedResult<T: Decodable>(forScript script: String) async throws(JavaScriptBridgeError) -> T
}

@MainActor
protocol JavaScriptCallbackEvaluator: AnyObject {
    func evaluate<T: Decodable>(
        script: String,
        resultType: T.Type,
        completion: @escaping (Result<T, Error>) -> Void
    )

    func decodedResult<T: Decodable>(
        forScript script: String,
        completion: @escaping (Result<T, Error>) -> Void
    )
}

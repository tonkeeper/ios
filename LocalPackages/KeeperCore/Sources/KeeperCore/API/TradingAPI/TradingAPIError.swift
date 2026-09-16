import Foundation
import TKLogging

enum TradingAPIError: Error {
    case badUrl(
        underlying: Error?
    )
    case badStatus(
        message: String
    )
    case notFound
    case badResponse(
        underlying: Error?
    )
    case transportError(
        underlying: Error?
    )
    case unknown(
        underlying: Error?
    )
}

extension TradingAPIError: LoggableError {
    var logDescription: String {
        let description = LogDescription(type: TradingAPIError.self)
        switch self {
        case let .badUrl(underlying):
            return description.with("case", "badUrl").with("underlying", error: underlying).text
        case let .badStatus(message):
            return description.with("case", "badStatus").with("message", message).text
        case .notFound:
            return description.with("case", "notFound").text
        case let .badResponse(underlying):
            return description.with("case", "badResponse").with("underlying", error: underlying).text
        case let .transportError(underlying):
            return description.with("case", "transportError").with("underlying", error: underlying).text
        case let .unknown(underlying):
            return description.with("case", "unknown").with("underlying", error: underlying).text
        }
    }
}

extension TradingAPIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case let .badUrl(error):
            "bad url, error: \(error?.localizedDescription ?? "nil")"
        case let .badStatus(message):
            message
        case .notFound:
            "Asset not found"
        case let .badResponse(error):
            "bad response, error: \(error?.localizedDescription ?? "nil")"
        case let .transportError(error):
            "network error, error: \(error?.localizedDescription ?? "nil")"
        case let .unknown(error):
            "unknown error, error: \(error?.localizedDescription ?? "nil")"
        }
    }
}

import Foundation
import HTTPTypes
import OpenAPIRuntime
import TKLogging

/// Every failure a generated client can produce — serialization, middleware, transport and
/// response decoding alike — reaches the caller wrapped in a `ClientError`. Without this the
/// whole chain collapses to `type=OpenAPIRuntime.ClientError` in the logs.
///
/// Deliberately narrower than `ClientError.description`: that one prints the request headers,
/// the operation input and both bodies, and exported logs travel to issue trackers.
extension ClientError: @retroactive LoggableError {
    public var logDescription: String {
        LogDescription(type: ClientError.self)
            .with("operationID", operationID)
            .with("method", request?.method.rawValue)
            .with("path", request?.loggedPath)
            .with("status", response.map { "\($0.status.code)" })
            .with("cause", causeDescription)
            .with("underlying", error: underlyingError)
            .text
    }
}

extension HTTPRequest {
    /// Query values carry search terms, addresses and country codes, so only the keys survive.
    var loggedPath: String? {
        guard let path else {
            return nil
        }
        let parts = path.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        guard let queryPart = parts.count > 1 ? parts[1] : nil, !queryPart.isEmpty else {
            return path
        }
        let keys = queryPart
            .split(separator: "&")
            .compactMap { $0.split(separator: "=", maxSplits: 1).first }
            .joined(separator: ",")
        return "\(parts[0])?\(keys)"
    }
}

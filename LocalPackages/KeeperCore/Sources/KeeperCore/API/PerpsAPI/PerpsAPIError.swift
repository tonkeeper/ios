import Foundation
import TKLogging
import TKPerpsAPI

/// What the service said about a refusal. `code` and `reason` are its machine
/// vocabulary — the catalog code in the envelope, and `details.reason`, which is
/// where the send contract puts what to do about it. `message` is fixed per code
/// and meant for logs, so nothing classifies on its text.
struct PerpsAPIFailure: Equatable, Sendable {
    let httpStatus: Int
    let code: String?
    let message: String?
    let retryable: Bool
    let reason: String?

    init(httpStatus: Int, code: String?, message: String?, retryable: Bool, reason: String?) {
        self.httpStatus = httpStatus
        self.code = code
        self.message = message
        self.retryable = retryable
        self.reason = reason
    }

    init(httpStatus: Int, body: Components.Schemas.ErrorResponse) {
        self.httpStatus = httpStatus
        code = body.code
        message = body.message
        retryable = body.retryable
        reason = body.details?.additionalProperties.value["reason"] as? String
    }

    /// A status the service answered without a body this client could read.
    static func undecoded(_ httpStatus: Int, message: String) -> Self {
        Self(httpStatus: httpStatus, code: nil, message: message, retryable: false, reason: nil)
    }

    var logText: String {
        [
            "status=\(httpStatus)",
            code.map { "code=\($0)" },
            reason.map { "reason=\($0)" },
            "retryable=\(retryable)",
            message.map { "message=\($0)" },
        ]
        .compactMap { $0 }
        .joined(separator: " ")
    }
}

enum PerpsAPIError: Error {
    case badUrl(underlying: Error?)
    case badStatus(PerpsAPIFailure)
    case unauthorized
    case notFound
    case conflict
    case badResponse(underlying: Error?)
    case transport(underlying: Error?)
    case unknown(underlying: Error?)

    var isResignRequired: Bool {
        guard case let .badStatus(failure) = self else { return false }
        return failure.reason == "resign_required"
    }
}

extension PerpsAPIError: LoggableError {
    var logDescription: String {
        let description = LogDescription(type: PerpsAPIError.self)
        switch self {
        case let .badUrl(underlying):
            return description.with("case", "badUrl").with("underlying", error: underlying).text
        case let .badStatus(failure):
            return description.with("case", "badStatus").with("failure", failure.logText).text
        case .unauthorized:
            return description.with("case", "unauthorized").text
        case .notFound:
            return description.with("case", "notFound").text
        case .conflict:
            return description.with("case", "conflict").text
        case let .badResponse(underlying):
            return description.with("case", "badResponse").with("underlying", error: underlying).text
        case let .transport(underlying):
            return description.with("case", "transport").with("underlying", error: underlying).text
        case let .unknown(underlying):
            return description.with("case", "unknown").with("underlying", error: underlying).text
        }
    }
}

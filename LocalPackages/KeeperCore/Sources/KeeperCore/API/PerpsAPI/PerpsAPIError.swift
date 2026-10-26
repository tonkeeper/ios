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
    /// `details.detail`: what a validation error names.
    let detail: String?
    /// `details.min_usd_amount`: the smallest deposit an `amount_too_low` quote would take, in dollars.
    let minUsdAmount: String?

    init(
        httpStatus: Int,
        code: String?,
        message: String?,
        retryable: Bool,
        reason: String?,
        detail: String? = nil,
        minUsdAmount: String? = nil
    ) {
        self.httpStatus = httpStatus
        self.code = code
        self.message = message
        self.retryable = retryable
        self.reason = reason
        self.detail = detail
        self.minUsdAmount = minUsdAmount
    }

    init(httpStatus: Int, body: Components.Schemas.ErrorResponse) {
        self.httpStatus = httpStatus
        code = body.code
        message = body.message
        retryable = body.retryable
        reason = body.details?.additionalProperties.value["reason"] as? String
        detail = body.details?.additionalProperties.value["detail"] as? String
        minUsdAmount = body.details?.additionalProperties.value["min_usd_amount"] as? String
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
            detail.map { "detail=\($0)" },
            minUsdAmount.map { "min_usd_amount=\($0)" },
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

    /// Lighter holds no live integrator approval for the account: it expired, or the account revoked it.
    var isIntegratorNotApproved: Bool {
        guard case let .badStatus(failure) = self else { return false }
        return failure.reason == "integrator_not_approved"
    }

    var isReadOnlyTokenUnavailable: Bool {
        guard case let .badStatus(failure) = self else { return false }
        return failure.code == "readonly_token_unavailable"
    }

    /// Another deposit is creating the address's Lighter account; refused only until that one closes.
    var isAccountCreationPending: Bool {
        guard case let .badStatus(failure) = self else { return false }
        return failure.reason == "account_creation_pending" || failure.code == "account_creation_pending"
    }

    var isAddressNotBound: Bool {
        guard case let .badStatus(failure) = self, failure.httpStatus == 409 else { return false }
        return failure.reason == "address_not_bound" || failure.code == "address_not_bound"
    }

    /// A read that needs the wallet's stored read-only token: no retry fixes a missing one, so it is
    /// issued and the read made once more.
    static func reissuingReadOnlyToken<T>(
        _ reissue: () async -> Bool,
        read: () async throws -> T
    ) async throws -> T {
        do {
            return try await read()
        } catch let error as PerpsAPIError where error.isReadOnlyTokenUnavailable {
            guard !Task.isCancelled, await reissue() else { throw error }
            return try await read()
        }
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

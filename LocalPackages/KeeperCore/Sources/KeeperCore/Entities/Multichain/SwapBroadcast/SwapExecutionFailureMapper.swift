/// Normalizes arbitrary stage errors into `MultichainSwapExecutionFailure`, so every
/// step of the swap pipeline reports the same typed failure to the confirmation UI.
enum SwapExecutionFailureMapper {
    static func failure(from error: Error) -> MultichainSwapExecutionFailure {
        if let failure = error as? MultichainSwapExecutionFailure {
            return failure
        }
        if let failure = error as? MultichainTransactionEmulationFailure {
            return self.failure(from: failure)
        }
        if let failure = error as? MultichainSwapAPIError {
            return self.failure(from: failure)
        }
        return .internal(reason: error.logDescription)
    }

    static func failure(
        from failure: MultichainTransactionEmulationFailure
    ) -> MultichainSwapExecutionFailure {
        .emulationFailed(kind: failure.executionErrorKind, reason: failure.logDescription)
    }

    static func failure(
        from failure: MultichainSwapAPIError
    ) -> MultichainSwapExecutionFailure {
        switch failure {
        case let .badRequest(message, code, requestId),
             let .notFound(message, code, requestId):
            return .preparationFailed(
                kind: kind(for: code, fallback: .badResponse),
                reason: apiReason(message: message, code: code, requestId: requestId)
            )
        case let .internalServerError(message, code, requestId):
            return .preparationFailed(
                kind: kind(for: code, fallback: .internalError),
                reason: apiReason(message: message, code: code, requestId: requestId)
            )
        case let .badResponse(diagnostic):
            return .preparationFailed(kind: .badResponse, reason: diagnostic.message)
        case let .transportError(diagnostic):
            return .preparationFailed(kind: .networkError, reason: diagnostic.message)
        case let .unknown(statusCode):
            let kind: MultichainSwapExecutionErrorKind = (500 ... 599).contains(statusCode)
                ? .internalError
                : .badResponse
            return .preparationFailed(kind: kind, reason: "unexpected HTTP status \(statusCode)")
        }
    }

    /// `prepare` rejects with the same normalized codes a quote carries, plus its own balance one.
    /// Without reading them every rejection reads to the user as a bad answer from a node, and the
    /// route-recovery ladder spends its retries on failures no fresh route can fix.
    private static func kind(
        for code: String?,
        fallback: MultichainSwapExecutionErrorKind
    ) -> MultichainSwapExecutionErrorKind {
        switch code ?? "" {
        case MultichainSwapProviderErrorCode.providerUnavailable.rawValue:
            return .providerUnavailable
        case MultichainSwapProviderErrorCode.minAmountNotMet.rawValue:
            return .dustAmount
        case MultichainSwapProviderErrorCode.assetNotSupported.rawValue,
             MultichainSwapProviderErrorCode.noRoute.rawValue,
             MultichainSwapAPIError.pairNotAllowedCode:
            return .unsupportedAsset
        case MultichainSwapAPIError.insufficientBalanceCode:
            return .insufficientBalance
        default:
            return fallback
        }
    }

    private static func apiReason(
        message: String,
        code: String?,
        requestId: String?
    ) -> String {
        [message, code, requestId].compactMap { $0 }.joined(separator: ", ")
    }
}

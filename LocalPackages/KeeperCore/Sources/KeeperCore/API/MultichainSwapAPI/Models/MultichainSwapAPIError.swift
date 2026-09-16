public enum MultichainSwapAPIError: Error, Sendable, Hashable {
    case badRequest(message: String, code: String?, requestId: String?)
    case notFound(message: String, code: String?, requestId: String?)
    case internalServerError(message: String, code: String?, requestId: String?)
    case badResponse(diagnostic: MultichainAPIDiagnostic)
    case transportError(diagnostic: MultichainAPIDiagnostic)
    case unknown(statusCode: Int)
}

public extension MultichainSwapAPIError {
    var isPairNotAllowed: Bool {
        code == Self.pairNotAllowedCode
    }
}

extension MultichainSwapAPIError {
    static let pairNotAllowedCode = "pair_not_allowed"
    static let insufficientBalanceCode = "insufficient_balance"

    var code: String? {
        switch self {
        case let .badRequest(_, code, _),
             let .notFound(_, code, _),
             let .internalServerError(_, code, _):
            return code
        case .badResponse, .transportError, .unknown:
            return nil
        }
    }
}

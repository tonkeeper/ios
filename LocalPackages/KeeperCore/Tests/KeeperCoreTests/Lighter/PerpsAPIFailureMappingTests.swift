@testable import KeeperCore
import XCTest

final class PerpsAPIFailureMappingTests: XCTestCase {
    private func failure(status: Int = 400, code: String? = nil, reason: String? = nil) -> PerpsAPIFailure {
        PerpsAPIFailure(httpStatus: status, code: code, message: nil, retryable: false, reason: reason)
    }

    func testTheSendReasonDecidesWhatToDoAboutARefusal() {
        XCTAssertEqual(
            PerpsTradingErrorMapper.map(failure(code: "validation_error", reason: "resign_required")),
            .stalePreparedTransaction
        )
        XCTAssertEqual(
            PerpsTradingErrorMapper.map(failure(code: "validation_error", reason: "order_gone")),
            .stalePreparedTransaction
        )
        XCTAssertEqual(
            PerpsTradingErrorMapper.map(failure(code: "validation_error", reason: "invalid_transaction")),
            .protocolFailure("validation_error")
        )
        XCTAssertEqual(
            PerpsTradingErrorMapper.map(failure(code: "validation_error", reason: "lighter_rejected")),
            .serverRejected("validation_error")
        )
    }

    func testTheEnvelopeCodeClassifiesEverythingElse() {
        XCTAssertEqual(PerpsTradingErrorMapper.map(failure(code: "validation_error")), .validation("validation_error"))
        XCTAssertEqual(PerpsTradingErrorMapper.map(failure(status: 409, code: "conflict")), .stalePreparedTransaction)
        XCTAssertEqual(PerpsTradingErrorMapper.map(failure(status: 401, code: "token_expired")), .authExpired)
        XCTAssertEqual(PerpsTradingErrorMapper.map(failure(status: 401, code: "token_revoked")), .credentialsRevoked)
        XCTAssertEqual(PerpsTradingErrorMapper.map(failure(status: 403, code: "wallet_forbidden")), .regionUnavailable)
        XCTAssertEqual(PerpsTradingErrorMapper.map(failure(status: 404, code: "not_found")), .positionNotFound)
        XCTAssertEqual(PerpsTradingErrorMapper.map(failure(status: 503, code: "upstream_unavailable")), .serverUnavailable)
    }

    func testStatusesWithoutAKnownCodeFallBackByClass() {
        XCTAssertEqual(PerpsTradingErrorMapper.map(failure(status: 429)), .rateLimited)
        XCTAssertEqual(PerpsTradingErrorMapper.map(failure(status: 400)), .validation("request failed"))
        XCTAssertEqual(PerpsTradingErrorMapper.map(failure(status: 502)), .serverUnavailable)
    }
}

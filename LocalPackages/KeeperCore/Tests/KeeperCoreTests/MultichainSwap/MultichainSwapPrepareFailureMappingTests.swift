@testable import KeeperCore
import XCTest

final class MultichainSwapPrepareFailureMappingTests: XCTestCase {
    /// What SwapKit's `near_intents` route actually answers with while the provider is down.
    func test_providerUnavailable_isReportedAsAnOutageAndNotAsABadNodeAnswer() {
        let failure = SwapExecutionFailureMapper.failure(
            from: MultichainSwapAPIError.badRequest(
                message: "provider temporarily unavailable, retry later: unableToBuildTransaction",
                code: "provider_unavailable",
                requestId: "ef24feee"
            )
        )

        XCTAssertEqual(kind(of: failure), .providerUnavailable)
    }

    func test_insufficientBalance_isReportedAsSuch() {
        XCTAssertEqual(
            kind(of: mapped(code: "insufficient_balance")),
            .insufficientBalance
        )
    }

    func test_minAmountNotMet_isReportedAsAnAmountTooSmall() {
        XCTAssertEqual(kind(of: mapped(code: "min_amount_not_met")), .dustAmount)
    }

    func test_unroutablePairCodes_areReportedAsAnUnsupportedAsset() {
        for code in ["asset_not_supported", "no_route", "pair_not_allowed"] {
            XCTAssertEqual(kind(of: mapped(code: code)), .unsupportedAsset, code)
        }
    }

    func test_anUnknownCode_keepsTheStatusBasedKind() {
        XCTAssertEqual(kind(of: mapped(code: "brand_new_backend_code")), .badResponse)
        XCTAssertEqual(kind(of: mapped(code: nil)), .badResponse)
        XCTAssertEqual(
            kind(of: SwapExecutionFailureMapper.failure(
                from: MultichainSwapAPIError.internalServerError(message: "boom", code: nil, requestId: nil)
            )),
            .internalError
        )
    }

    /// A 500 that names the outage is the same outage, not an internal error of ours.
    func test_theCodeWinsOverTheStatus() {
        XCTAssertEqual(
            kind(of: SwapExecutionFailureMapper.failure(
                from: MultichainSwapAPIError.internalServerError(
                    message: "provider temporarily unavailable, retry later",
                    code: "provider_unavailable",
                    requestId: nil
                )
            )),
            .providerUnavailable
        )
    }

    func test_theReasonKeepsTheBackendsMessageCodeAndRequestId() {
        guard case let .preparationFailed(_, reason) = mapped(
            code: "provider_unavailable",
            message: "provider temporarily unavailable, retry later: unableToBuildTransaction",
            requestId: "ef24feee"
        ) else {
            return XCTFail("Expected a preparation failure")
        }

        XCTAssertTrue(reason.contains("unableToBuildTransaction"), reason)
        XCTAssertTrue(reason.contains("provider_unavailable"), reason)
        XCTAssertTrue(reason.contains("ef24feee"), reason)
    }
}

private extension MultichainSwapPrepareFailureMappingTests {
    func mapped(
        code: String?,
        message: String = "rejected",
        requestId: String? = "request"
    ) -> MultichainSwapExecutionFailure {
        SwapExecutionFailureMapper.failure(
            from: MultichainSwapAPIError.badRequest(message: message, code: code, requestId: requestId)
        )
    }

    func kind(of failure: MultichainSwapExecutionFailure) -> MultichainSwapExecutionErrorKind? {
        guard case let .preparationFailed(kind, _) = failure else {
            return nil
        }
        return kind
    }
}

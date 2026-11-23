@testable import KeeperCore
import XCTest

final class MultichainSwapTonBatteryRelayFailureTests: XCTestCase {
    func test_refusalForLackOfFunds_readsAsRefused() {
        let failure = MultichainSwapTonBatteryFeeEngine.relayFailure(
            .sendFailed(
                message: "failed to single battery send due to error: 402",
                refusal: RelayerRefusal(status: 402, code: "err-gasless-balance")
            ),
            payloadId: "main"
        )

        XCTAssertEqual(
            failure,
            .broadcastRefused(
                payloadId: "main",
                kind: .insufficientBalance,
                reason: "battery relay rejected the swap: failed to single battery send due to error: 402"
            )
        )
    }

    /// The relayer may already hold the message, so the swap must not be signed again.
    func test_anyOtherFailedSend_leavesTheOutcomeUnknown() {
        let refusals: [RelayerRefusal?] = [nil, RelayerRefusal(status: 400, code: "err-gasless-pending-messages")]
        for refusal in refusals {
            let failure = MultichainSwapTonBatteryFeeEngine.relayFailure(
                .sendFailed(message: "refused", refusal: refusal),
                payloadId: "main"
            )

            XCTAssertEqual(
                failure,
                .broadcastFailed(payloadId: "main", kind: .unknown, reason: "battery relay rejected the swap: refused")
            )
        }
    }
}

import BigInt
@testable import KeeperCore
import XCTest

final class TronTransferFeeEstimateTests: XCTestCase {
    func test_withoutActivation_selfPaidCostIsThePerByteBurn() {
        let estimate = makeEstimate(requiredTRXSun: 268_000, destinationActivationSun: 0)

        XCTAssertEqual(estimate.selfPaidTRXSun, 268_000)
        XCTAssertFalse(estimate.requiresSelfPaidTRX)
    }

    func test_freeBandwidthCoversTheTransfer_selfPaidCostIsZero() {
        let estimate = makeEstimate(requiredTRXSun: 0, destinationActivationSun: 0)

        XCTAssertEqual(estimate.selfPaidTRXSun, 0)
        XCTAssertFalse(estimate.requiresSelfPaidTRX)
    }

    /// Creating the destination account replaces this transfer's per-byte charge, so the activation
    /// burn is the whole cost rather than an addition to it.
    func test_withActivation_selfPaidCostIsTheActivationBurn() {
        let estimate = makeEstimate(requiredTRXSun: 0, destinationActivationSun: 1_100_000)

        XCTAssertEqual(estimate.selfPaidTRXSun, 1_100_000)
        XCTAssertTrue(estimate.requiresSelfPaidTRX)
    }

    func test_withActivation_perByteBurnIsNotAddedOnTop() {
        let estimate = makeEstimate(requiredTRXSun: 268_000, destinationActivationSun: 1_000_000)

        XCTAssertEqual(estimate.selfPaidTRXSun, 1_000_000)
    }
}

private extension TronTransferFeeEstimateTests {
    func makeEstimate(
        requiredTRXSun: BigUInt,
        destinationActivationSun: BigUInt
    ) -> TronTransferFeeEstimate {
        TronTransferFeeEstimate(
            energy: 0,
            bandwidth: 268,
            requiredBatteryCharges: 0,
            requiredTRXSun: requiredTRXSun,
            destinationActivationSun: destinationActivationSun,
            requiredTONAmountNano: nil,
            tonFeeAddress: nil
        )
    }
}

@testable import KeeperCore
import PerpsModels
import XCTest

final class PerpsReviewDriftTests: XCTestCase {
    func testToleranceAllowsSmallMovesAndRejectsMissingOrNonfiniteValues() {
        XCTAssertTrue(PerpsReviewDrift.near(100, 102))
        XCTAssertTrue(PerpsReviewDrift.near(100, 98))
        XCTAssertFalse(PerpsReviewDrift.near(100, 102.01))
        XCTAssertFalse(PerpsReviewDrift.near(100, 97.99))
        XCTAssertTrue(PerpsReviewDrift.near(nil, nil))
        XCTAssertFalse(PerpsReviewDrift.near(nil, 100))
        XCTAssertFalse(PerpsReviewDrift.near(100, nil))
        for invalid in [Double.nan, .infinity, -.infinity] {
            XCTAssertFalse(PerpsReviewDrift.near(invalid, 100))
            XCTAssertFalse(PerpsReviewDrift.nearUsd(invalid, 100))
            XCTAssertFalse(PerpsReviewDrift.near(100, invalid))
            XCTAssertFalse(PerpsReviewDrift.nearUsd(100, invalid))
        }
        XCTAssertTrue(PerpsReviewDrift.nearUsd(0, 0.01))
        XCTAssertFalse(PerpsReviewDrift.nearUsd(0, 0.011))
    }

    func testOpenRejectsDriftInEachOrderTerm() {
        let shown = open()
        XCTAssertTrue(shown.admits(shown))
        XCTAssertTrue(shown.admits(open(entry: 101.5, worst: 102.5)))
        for changed in [
            open(base: 11), open(entry: 105), open(worst: 106), open(liquidation: 95),
            open(margin: 110), open(fee: 2), open(notional: 1100), open(isolated: true), open(rate: 0.095),
        ] {
            XCTAssertFalse(shown.admits(changed), "\(changed)")
        }
    }

    func testCloseRejectsChangedSizeSideLeverageAndPrice() {
        let shown = close()
        XCTAssertTrue(shown.admits(shown))
        for changed in [
            close(base: 11), close(side: .short), close(leverage: 20), close(worst: 90),
            close(margin: 110), close(fee: 2), close(rate: 0.095),
        ] {
            XCTAssertFalse(shown.admits(changed), "\(changed)")
        }
    }

    func testResizeBoundsTheOrderDeltaEvenWhenThePositionItselfBarelyChanges() {
        let shown = size(old: 1000, new: 1001)
        XCTAssertTrue(shown.admits(shown))
        XCTAssertTrue(shown.admits(size(old: 1000.1, new: 1001.1)))
        XCTAssertFalse(shown.admits(size(old: 1000, new: 1002)))
        XCTAssertFalse(shown.admits(size(old: 1001, new: 1002.1)))
        XCTAssertFalse(shown.admits(size(old: 1000, new: 999)))
        XCTAssertFalse(shown.admits(size(old: 1000, new: 0, whole: true)))
        XCTAssertFalse(shown.admits(size(old: 1000, new: 1001, rate: 0.095)))
    }

    func testMarginRejectsChangedPositionAndLiquidationTerms() {
        let shown = margin()
        XCTAssertTrue(shown.admits(shown))
        for changed in [
            margin(side: .short), margin(leverage: 20), margin(amount: 20),
            margin(old: 110), margin(new: 120), margin(liquidation: 95),
        ] {
            XCTAssertFalse(shown.admits(changed), "\(changed)")
        }
    }

    private func open(
        base: Double = 10, entry: Double = 100, worst: Double = 101, liquidation: Double = 90,
        margin: Double = 100, fee: Double = 1, rate: Double = 0.09, notional: Double = 1000, isolated: Bool = false
    ) -> PerpsOpenOrderReview {
        .init(
            symbol: "ETH", marginUsd: margin, entryPrice: entry, liquidationPrice: liquidation,
            notionalUsd: notional, baseSize: base, estimatedFeeUsd: fee, feeRatePercent: rate, liquidationUnavailableReason: nil,
            setsIsolatedMargin: isolated, worstPrice: worst
        )
    }

    private func close(
        base: Double = 10, side: PerpsTradeSide = .long, leverage: Double = 10,
        worst: Double = 99, margin: Double = 100, fee: Double = 1, rate: Double = 0.09
    ) -> PerpsCloseReview {
        .init(
            symbol: "ETH", side: side, leverage: leverage, marginUsd: margin, notionalUsd: 1000,
            baseSize: base, estimatedFeeUsd: fee, feeRatePercent: rate, estimatedPnlUsd: 0, estimatedReceiveUsd: 99, worstPrice: worst
        )
    }

    private func size(old: Double, new: Double, whole: Bool = false, rate: Double = 0.09) -> PerpsSizeChangeReview {
        .init(
            symbol: "ETH", direction: .add, side: .long, leverage: 10, marginDeltaUsd: 10,
            entryPrice: .init(old: 100, new: 100), notionalUsd: .init(old: 100_000, new: 100_100),
            baseSize: .init(old: old, new: new), liquidationPrice: .init(old: 90, new: 90),
            liquidationUnavailableReason: nil, estimatedFeeUsd: 1, feeRatePercent: rate, closesWholePosition: whole,
            worstPrice: 101
        )
    }

    private func margin(
        side: PerpsTradeSide = .long, leverage: Double = 10, amount: Double = 10,
        old: Double = 100, new: Double = 110, liquidation: Double = 90
    ) -> PerpsMarginChangeReview {
        .init(
            symbol: "ETH", direction: .add, side: side, leverage: leverage, amountUsd: amount,
            allocatedMargin: .init(old: old, new: new), liquidationPrice: .init(old: 91, new: liquidation),
            liquidationUnavailableReason: nil, isImmediateRisk: false
        )
    }
}

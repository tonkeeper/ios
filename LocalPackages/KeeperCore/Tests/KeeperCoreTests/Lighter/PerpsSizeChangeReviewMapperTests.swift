import ChainKit
@testable import KeeperCore
import XCTest

/// The "before" figures are the caller's, the "after" ones are the venue's, and
/// both are decoded with the market's own scale rather than a default.
final class PerpsSizeChangeReviewMapperTests: XCTestCase {
    private let scale = PerpsScale(priceDecimals: 4, baseDecimals: 5, quoteDecimals: 9)

    func testAddKeepsTheOldEntryAndProjectsTheNewNotional() {
        let review = PerpetualReview.Add(
            side: PerpsSide.long_,
            kind: PerpsOrderKind.market,
            scale: scale,
            marginBudgetQuote: 10_000_000_000,
            initialMarginBps: 1000,
            baseAmount: 50000,
            notionalQuote: 150_000_000_000,
            referencePrice: 30_000_000,
            estimatedEntryPrice: 30_000_000,
            mergedBaseAmount: 150_000,
            mergedEntryPrice: 23_333_333,
            estimatedFeeQuote: 1_000_000_000,
            estimatedCollateralQuote: 40_000_000_000,
            priceBoundOrLimit: 31_000_000,
            maxNotionalQuote: 150_000_000_000,
            maxFeeQuote: 1_000_000_000,
            takeProfitTrigger: nil,
            stopLossTrigger: nil,
            liquidationPrice: nil,
            liquidationUnavailableReason: nil,
            isImmediateRisk: false
        )

        let mapped = PerpsPlannerMapping.addReview(
            review,
            symbol: "BTC",
            direction: .add,
            marginDeltaUsd: 10,
            oldBase: 100_000,
            oldEntry: 20_000_000,
            oldNotionalUsd: 2000
        )

        XCTAssertEqual(mapped.direction, PerpsSizeChangeDirection.add)
        XCTAssertEqual(mapped.baseSize.old, 1, accuracy: 1e-9)
        XCTAssertEqual(mapped.baseSize.new, 1.5, accuracy: 1e-9)
        XCTAssertEqual(mapped.entryPrice.old, 2000, accuracy: 1e-6)
        XCTAssertEqual(mapped.entryPrice.new, 2333.3333, accuracy: 1e-3)
        XCTAssertEqual(mapped.notionalUsd.old, 2000, accuracy: 1e-9)
        XCTAssertEqual(mapped.notionalUsd.new, 3500, accuracy: 1e-3)
    }

    func testReduceKeepsTheEntryAndShrinksTheNotional() {
        let review = PerpetualReview.Close(
            side: PerpsSide.long_,
            scale: scale,
            fullExit: false,
            closingBaseAmount: 40000,
            estimatedFillBaseAmount: 40000,
            remainingBaseAmount: 60000,
            notionalQuote: 80_000_000_000,
            referencePrice: 20_000_000,
            estimatedExitPrice: 20_000_000,
            estimatedFeeQuote: 1_000_000_000,
            estimatedRealizedPnlQuote: 0,
            estimatedReceiveQuote: 39_000_000_000,
            estimatedReturnedMarginQuote: 40_000_000_000,
            priceBound: 19_000_000,
            maxNotionalQuote: 80_000_000_000,
            maxFeeQuote: 1_000_000_000,
            liquidationPrice: nil,
            liquidationUnavailableReason: nil,
            isImmediateRisk: false
        )

        let mapped = PerpsPlannerMapping.closeSizeReview(
            review,
            symbol: "BTC",
            direction: .reduce,
            marginDeltaUsd: 40,
            leverage: 5,
            oldBase: 100_000,
            oldEntry: 20_000_000,
            oldNotionalUsd: 2000
        )

        XCTAssertEqual(mapped.direction, PerpsSizeChangeDirection.reduce)
        XCTAssertEqual(mapped.baseSize.old, 1, accuracy: 1e-9)
        XCTAssertEqual(mapped.baseSize.new, 0.6, accuracy: 1e-9)
        XCTAssertEqual(mapped.entryPrice.new, 2000, accuracy: 1e-6)
        XCTAssertEqual(mapped.notionalUsd.old, 2000, accuracy: 1e-9)
        XCTAssertEqual(mapped.notionalUsd.new, 1200, accuracy: 1e-9)
    }
}

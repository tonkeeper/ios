import ChainKit
@testable import KeeperCore
import XCTest

/// The margin review blends the SDK's UpdateMargin preview with the live
/// position. These tests lock the fallback and sign rules of that blend.
final class PerpsMarginChangeReviewMapperTests: XCTestCase {
    func testSideAndSymbolComeFromPosition() {
        let review = PerpsMarginChangeReviewMapper.map(
            direction: .add,
            review: Self.makeMarginReview(),
            position: Self.makePosition(side: LighterTradeSide.short_)
        )
        XCTAssertEqual(review.side, .short)
        XCTAssertEqual(review.symbol, "BTC")
    }

    func testReduceFallsBackToSignedDeltaWhenReviewOmitsMarginAfter() {
        let review = PerpsMarginChangeReviewMapper.map(
            direction: .reduce,
            review: Self.makeMarginReview(usdc: 10, allocatedMarginBefore: nil, allocatedMarginAfter: nil),
            position: Self.makePosition(allocatedMargin: 30)
        )
        XCTAssertEqual(review.allocatedMargin.old, 30)
        XCTAssertEqual(review.allocatedMargin.new, 20)
    }

    func testAddPrefersReviewMarginPairOverPosition() {
        let review = PerpsMarginChangeReviewMapper.map(
            direction: .add,
            review: Self.makeMarginReview(usdc: 20, allocatedMarginBefore: 20.5, allocatedMarginAfter: 40.5),
            position: Self.makePosition(allocatedMargin: 19)
        )
        XCTAssertEqual(review.allocatedMargin.old, 20.5)
        XCTAssertEqual(review.allocatedMargin.new, 40.5)
    }

    func testLiquidationPairFallsBackToPositionForTheOldValue() {
        let review = PerpsMarginChangeReviewMapper.map(
            direction: .add,
            review: Self.makeMarginReview(liquidationPriceBefore: nil, estimatedLiquidationPriceAfter: 63639.99),
            position: Self.makePosition(liquidationPrice: 64141.75)
        )
        XCTAssertEqual(review.liquidationPrice?.old, 64141.75)
        XCTAssertEqual(review.liquidationPrice?.new, 63639.99)
        XCTAssertNil(review.liquidationUnavailableReason)
    }

    func testMissingLiquidationAfterMapsUnavailableReasonInsteadOfPair() {
        let review = PerpsMarginChangeReviewMapper.map(
            direction: .reduce,
            review: Self.makeMarginReview(
                liquidationPriceBefore: 64141.75,
                estimatedLiquidationPriceAfter: nil,
                liquidationUnavailableReason: LighterLiquidationUnavailable.missingMark
            ),
            position: Self.makePosition()
        )
        XCTAssertNil(review.liquidationPrice)
        XCTAssertEqual(review.liquidationUnavailableReason, .missingMark)
    }

    // MARK: - Fixtures

    private static func makeMarginReview(
        usdc: Double = 20,
        allocatedMarginBefore: Double? = 20.5,
        allocatedMarginAfter: Double? = 40.5,
        liquidationPriceBefore: Double? = 64141.75,
        estimatedLiquidationPriceAfter: Double? = 63639.99,
        isImmediateRisk: Bool = false,
        liquidationUnavailableReason: LighterLiquidationUnavailable? = nil
    ) -> LighterMarginReview {
        LighterMarginReview(
            marketId: 1,
            direction: LighterMarginDirection.add,
            usdc: usdc,
            usdcScaled: Int64(usdc * 1_000_000),
            allocatedMarginBefore: allocatedMarginBefore.map { KotlinDouble(value: $0) },
            allocatedMarginAfter: allocatedMarginAfter.map { KotlinDouble(value: $0) },
            liquidationPriceBefore: liquidationPriceBefore.map { KotlinDouble(value: $0) },
            estimatedLiquidationPriceAfter: estimatedLiquidationPriceAfter.map { KotlinDouble(value: $0) },
            isImmediateRisk: isImmediateRisk,
            liquidationUnavailableReason: liquidationUnavailableReason
        )
    }

    private static func makePosition(
        side: LighterTradeSide = LighterTradeSide.long_,
        size: Double = 0.008,
        avgEntryPrice: Double = 66000,
        allocatedMargin: Double = 20,
        liquidationPrice: Double = 64141.75
    ) -> LighterOpenPosition {
        LighterOpenPosition(
            marketId: 1,
            symbol: "BTC",
            side: side,
            size: size,
            avgEntryPrice: avgEntryPrice,
            allocatedMargin: allocatedMargin,
            liquidationPrice: liquidationPrice,
            unrealizedPnl: 0.5,
            marginMode: 1,
            leverage: KotlinDouble(value: 27),
            fundingPaid: nil
        )
    }
}

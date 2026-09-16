import ChainKit
@testable import KeeperCore
import XCTest

/// The close review blends two SDK sources: the position being closed (side,
/// margin, leverage) and the closing order's review (size, fee, PnL, receive).
/// These tests lock the non-obvious parts of that blend.
final class PerpsCloseReviewMapperTests: XCTestCase {
    func testSideComesFromPositionNotClosingOrder() {
        let review = PerpsCloseReviewMapper.map(
            review: Self.makeOrderReview(side: LighterTradeSide.short_),
            position: Self.makePosition(side: LighterTradeSide.long_)
        )
        XCTAssertEqual(review.side, .long)
    }

    func testLeverageComesFromPositionWithPositionNotionalFallback() {
        let fromPosition = PerpsCloseReviewMapper.map(
            review: Self.makeOrderReview(notionalUsd: 540),
            position: Self.makePosition(allocatedMargin: 20, leverage: 27)
        )
        XCTAssertEqual(fromPosition.marginUsd, 20)
        XCTAssertEqual(fromPosition.leverage, 27)

        let derived = PerpsCloseReviewMapper.map(
            review: Self.makeOrderReview(notionalUsd: 540),
            position: Self.makePosition(allocatedMargin: 20, leverage: nil)
        )
        XCTAssertEqual(derived.leverage, 26)

        let unavailable = PerpsCloseReviewMapper.map(
            review: Self.makeOrderReview(),
            position: Self.makePosition(allocatedMargin: 0, leverage: nil)
        )
        XCTAssertNil(unavailable.leverage)
    }

    func testPnlPercentIsReturnOnMargin() {
        let review = PerpsCloseReviewMapper.map(
            review: Self.makeOrderReview(estimatedPnlUsd: 0.5),
            position: Self.makePosition(allocatedMargin: 20)
        )
        XCTAssertEqual(review.estimatedPnlPercent ?? 0, 2.5, accuracy: 0.0001)

        let zeroMargin = PerpsCloseReviewMapper.map(
            review: Self.makeOrderReview(estimatedPnlUsd: 0.5),
            position: Self.makePosition(allocatedMargin: 0)
        )
        XCTAssertNil(zeroMargin.estimatedPnlPercent)
    }

    func testPartialFillMapsOnlyExecutableSizeAndMargin() {
        let review = PerpsCloseReviewMapper.map(
            review: Self.makeOrderReview(baseSize: 0.01, estimatedBaseFilled: 0.003),
            position: Self.makePosition(size: 0.01, allocatedMargin: 20)
        )

        XCTAssertEqual(review.baseSize, 0.003, accuracy: 0.000001)
        XCTAssertEqual(review.marginUsd, 6, accuracy: 0.000001)
    }

    // MARK: - Fixtures

    private static func makeOrderReview(
        side: LighterTradeSide = LighterTradeSide.short_,
        notionalUsd: Double = 540,
        baseSize: Double = 0.00781,
        estimatedBaseFilled: Double? = nil,
        estimatedPnlUsd: Double? = 0.5
    ) -> LighterOrderReview {
        LighterOrderReview(
            marketId: 1,
            symbol: "BTC",
            side: side,
            kind: LighterOrderKind.market,
            reduceOnly: true,
            baseAmount: 781,
            baseSize: baseSize,
            price: 0,
            priceHuman: 66141.70,
            notionalUsd: notionalUsd,
            estimatedFeeUsd: KotlinDouble(value: 0.144),
            clientOrderIndex: 0,
            takeProfit: nil,
            stopLoss: nil,
            fillWorstPrice: nil,
            quoteFilled: nil,
            estimatedBaseFilled: estimatedBaseFilled.map { KotlinDouble(value: $0) },
            maintenanceMarginFraction: nil,
            estimatedPnlUsd: estimatedPnlUsd.map { KotlinDouble(value: $0) },
            estimatedReceiveUsd: KotlinDouble(value: 20.34),
            positionAfter: nil
        )
    }

    private static func makePosition(
        side: LighterTradeSide = LighterTradeSide.long_,
        size: Double = 0.00781,
        allocatedMargin: Double = 20,
        leverage: Double? = 27
    ) -> LighterOpenPosition {
        LighterOpenPosition(
            marketId: 1,
            symbol: "BTC",
            side: side,
            size: size,
            avgEntryPrice: 66541.70,
            allocatedMargin: allocatedMargin,
            liquidationPrice: 64141.75,
            unrealizedPnl: 0.5,
            marginMode: 1,
            leverage: leverage.map { KotlinDouble(value: $0) },
            fundingPaid: nil
        )
    }
}

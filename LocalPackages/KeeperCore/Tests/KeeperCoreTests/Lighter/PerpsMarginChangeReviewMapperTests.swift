import ChainKit
@testable import KeeperCore
import XCTest

/// The scale comes from the market, never from an assumption, so every figure is
/// decoded with a non-default one.
final class PerpsMarginChangeReviewMapperTests: XCTestCase {
    private let scale = PerpsScale(priceDecimals: 4, baseDecimals: 5, quoteDecimals: 9)

    func testReduceDecodesBothSidesOfTheChangeWithTheMarketScale() {
        let review = PerpetualReview.Margin(
            scale: scale,
            addToPosition: false,
            amountQuote: 10_000_000_000,
            allocatedMarginAfterQuote: 20_000_000_000,
            liquidationPrice: KotlinLong(value: 636_399_900),
            liquidationUnavailableReason: nil,
            isImmediateRisk: false
        )

        let mapped = PerpsPlannerMapping.marginReview(
            review,
            symbol: "BTC",
            direction: .reduce,
            side: .short,
            leverage: 10,
            allocatedBefore: 30_000_000_000,
            liquidationBefore: 641_417_500
        )

        XCTAssertEqual(mapped.symbol, "BTC")
        XCTAssertEqual(mapped.side, .short)
        XCTAssertEqual(mapped.allocatedMargin.old, 30, accuracy: 1e-9)
        XCTAssertEqual(mapped.allocatedMargin.new, 20, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(mapped.liquidationPrice).old, 64141.75, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(mapped.liquidationPrice).new, 63639.99, accuracy: 1e-6)
        XCTAssertNil(mapped.liquidationUnavailableReason)
    }

    func testMissingLiquidationAfterCarriesTheVenueReason() {
        let review = PerpetualReview.Margin(
            scale: scale,
            addToPosition: false,
            amountQuote: 10_000_000_000,
            allocatedMarginAfterQuote: 20_000_000_000,
            liquidationPrice: nil,
            liquidationUnavailableReason: PerpsLiquidationUnavailable.flatposition,
            isImmediateRisk: false
        )

        let mapped = PerpsPlannerMapping.marginReview(
            review,
            symbol: "BTC",
            direction: .reduce,
            side: .long,
            leverage: nil,
            allocatedBefore: 30_000_000_000,
            liquidationBefore: nil
        )

        XCTAssertNil(mapped.liquidationPrice)
        XCTAssertEqual(mapped.liquidationUnavailableReason, PerpsLiquidationUnavailableReason.flatPosition)
    }
}

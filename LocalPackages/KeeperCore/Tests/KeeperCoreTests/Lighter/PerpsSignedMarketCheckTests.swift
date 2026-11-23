@testable import KeeperCore
import PerpsModels
import TKPerpsAPI
import XCTest

final class PerpsSignedMarketCheckTests: XCTestCase {
    func testAMarketServedAsSignedPasses() throws {
        let signed = try check(market)

        XCTAssertEqual(signed, .matching(market))
    }

    func testMinimumsWrittenWithOtherTrailingZerosAreTheSameMinimums() throws {
        let signed = PerpsSignedMarket.matching(market)
        let config = PerpsSecurityConfig.listing(
            PerpsSignedMarket(
                marketId: signed.marketId,
                symbol: signed.symbol,
                priceDecimals: signed.priceDecimals,
                sizeDecimals: signed.sizeDecimals,
                quoteDecimals: signed.quoteDecimals,
                minBaseAmount: "0.0550",
                minQuoteAmount: "10.000000",
                maxLeverage: signed.maxLeverage
            )
        )

        XCTAssertNoThrow(try PerpsSignedMarketCheck.signedMarket(marketId: 2, market: market, config: config))
    }

    func testAPriceScaleOneDigitLargerThanSignedIsRefused() {
        assertMismatch(withPriceDecimals(4))
    }

    func testASizeScaleOneDigitLargerThanSignedIsRefused() {
        assertMismatch(withSizeDecimals(4))
    }

    func testAPriceScaleOneLessAndASizeScaleOneMoreWithTheSameSumAreRefused() {
        assertMismatch(withSizeDecimals(4, priceDecimals: 2))
    }

    func testAMinimumSizeOtherThanTheSignedOneIsRefused() {
        var served = market
        served.min_size_base = "0.050"
        assertMismatch(served)
        served.min_size_base = nil
        assertMismatch(served)
    }

    func testAMinimumNotionalOtherThanTheSignedOneIsRefused() {
        var served = market
        served.min_size_quote = "5"
        assertMismatch(served)
        served.min_size_quote = ""
        assertMismatch(served)
    }

    func testAMinimumWhoseNumberOnlyStartsLikeTheSignedOneIsRefused() {
        for malformed in ["10abc", "10,5", " 10", "1e1"] {
            var served = market
            served.min_size_quote = malformed
            assertMismatch(served)
        }
    }

    func testALeverageCeilingOtherThanTheSignedOneIsRefused() {
        var served = market
        served.max_leverage = 50
        assertMismatch(served)
        served.max_leverage = 20
        assertMismatch(served)
        served.max_leverage = nil
        assertMismatch(served)
    }

    func testAMarketServedForAnotherIndexThanTheRequestedOneIsRefused() {
        var served = market
        served.market_index = 1
        let config = PerpsSecurityConfig.listing(.matching(market), .matching(served))

        XCTAssertThrowsError(try PerpsSignedMarketCheck.signedMarket(marketId: 2, market: served, config: config)) { error in
            XCTAssertTrue(isMismatch(error))
        }
    }

    func testAServedSymbolOtherThanTheSignedOneIsRefused() {
        var served = market
        served.symbol = "BTC"
        assertMismatch(served)
        served.symbol = "sol"
        assertMismatch(served)
        served.symbol = nil
        assertMismatch(served)
    }

    func testAMarketNumberASignedOrderCannotCarryIsUnavailableEvenWhenListed() {
        for marketId in [Int64(Int16.max) + 1, -1] {
            var served = market
            served.market_index = Int(marketId)
            let listed = PerpsSignedMarket.matching(served)

            XCTAssertThrowsError(
                try PerpsSignedMarketCheck.signedMarket(marketId: marketId, market: served, config: .listing(listed))
            ) { error in
                XCTAssertEqual((error as? PerpsSignedMarketRefusal)?.error, .tradingUnavailable)
            }
        }
    }

    func testAMarketTheSignedConfigDoesNotListIsUnavailable() {
        XCTAssertThrowsError(
            try PerpsSignedMarketCheck.signedMarket(marketId: 2, market: market, config: .listing())
        ) { error in
            XCTAssertEqual((error as? PerpsSignedMarketRefusal)?.error, .tradingUnavailable)
        }
    }

    func testAMarketTheSignedConfigAllowsNoLeverageOnIsUnavailable() {
        var served = market
        served.max_leverage = 0
        let config = PerpsSecurityConfig.listing(.matching(served))

        XCTAssertThrowsError(try PerpsSignedMarketCheck.signedMarket(marketId: 2, market: served, config: config)) { error in
            XCTAssertEqual((error as? PerpsSignedMarketRefusal)?.error, .tradingUnavailable)
        }
    }

    func testNoVerifiedConfigIsUnavailableWithoutCountingAsASignedRefusal() {
        XCTAssertThrowsError(try PerpsSignedMarketCheck.signedMarket(marketId: 2, market: market, config: nil)) { error in
            XCTAssertEqual(error as? PerpsTradingError, .tradingUnavailable)
            XCTAssertNil(error as? PerpsSignedMarketRefusal)
        }
    }

    func testARefusalReachesTheScreenAsItsTradingError() {
        let refusal = PerpsSignedMarketRefusal(error: .tradingUnavailable, reason: "not listed")

        XCTAssertEqual(PerpsTradingErrorMapper.map(refusal), .tradingUnavailable)
    }
}

private extension PerpsSignedMarketCheckTests {
    var market: Components.Schemas.Market {
        Components.Schemas.Market(
            market_index: 2,
            symbol: "SOL",
            status: "active",
            price_decimals: 3,
            size_decimals: 3,
            tick_size: "0.001",
            step_size: "0.001",
            min_size_base: "0.055",
            min_size_quote: "10.000000",
            max_leverage: 25,
            maker_fee_pct: "0",
            taker_fee_pct: "0",
            initial_margin_fraction: 666,
            maintenance_margin_fraction: 240
        )
    }

    func check(_ served: Components.Schemas.Market) throws -> PerpsSignedMarket {
        try PerpsSignedMarketCheck.signedMarket(marketId: 2, market: served, config: .listing(.matching(market)))
    }

    func withPriceDecimals(_ decimals: Int) -> Components.Schemas.Market {
        var served = market
        served.price_decimals = decimals
        return served
    }

    func withSizeDecimals(_ decimals: Int, priceDecimals: Int? = nil) -> Components.Schemas.Market {
        var served = market
        served.size_decimals = decimals
        if let priceDecimals {
            served.price_decimals = priceDecimals
        }
        return served
    }

    func assertMismatch(_ served: Components.Schemas.Market, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try check(served), file: file, line: line) { error in
            XCTAssertTrue(isMismatch(error), "\(error)", file: file, line: line)
        }
    }

    func isMismatch(_ error: Error) -> Bool {
        guard case .validation = (error as? PerpsSignedMarketRefusal)?.error else { return false }
        return true
    }
}

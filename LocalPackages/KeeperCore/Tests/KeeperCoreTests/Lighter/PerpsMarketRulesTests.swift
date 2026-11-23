import ChainKit
@testable import KeeperCore
import TKPerpsAPI
import XCTest

final class PerpsMarketRulesTests: XCTestCase {
    func testTheLeverageLimitComesFromTheSignedMaxLeverageNotTheVenueDefault() throws {
        let rules = try makeRules(maxLeverage: 50, initialMarginFraction: 500, maintenanceMarginFraction: 100)

        XCTAssertEqual(rules.minInitialMarginBps, 200)
        XCTAssertEqual(rules.maxInitialMarginBps, 10000)
    }

    func testEveryLeverageTheSliderOffersFitsInsideTheRules() throws {
        for (maxLeverage, defaultFraction) in [(50, 500), (25, 666), (20, 666), (3, 3333)] {
            let rules = try makeRules(
                maxLeverage: maxLeverage,
                initialMarginFraction: defaultFraction,
                maintenanceMarginFraction: 100
            )
            for leverage in 1 ... maxLeverage {
                let asked = PerpsPlannerMapping.initialMarginBps(leverage: Double(leverage))
                XCTAssertTrue(
                    (rules.minInitialMarginBps ... rules.maxInitialMarginBps).contains(asked),
                    "\(leverage)x on a \(maxLeverage)x market asks \(asked) bps, outside \(rules.minInitialMarginBps)...\(rules.maxInitialMarginBps)"
                )
            }
        }
    }

    func testAPositionOpenedElsewhereAboveTheDefaultLeverageIsStillServed() throws {
        let rules = try makeRules(maxLeverage: 50, initialMarginFraction: 500, maintenanceMarginFraction: 100)
        let openedAt30x = PerpsPlannerMapping.initialMarginBps(leverage: 30)

        XCTAssertEqual(openedAt30x, 334)
        XCTAssertTrue((rules.minInitialMarginBps ... rules.maxInitialMarginBps).contains(openedAt30x))
    }

    func testTheSignedLeverageLimitWinsOverTheServedDefaultFraction() throws {
        let rules = try makeRules(maxLeverage: 25, initialMarginFraction: 666, maintenanceMarginFraction: 100)

        XCTAssertEqual(rules.minInitialMarginBps, 400)
    }

    func testTheQuoteScaleAndMinimumsAreTheSignedOnes() throws {
        let market = makeMarket(maxLeverage: 50, initialMarginFraction: 500, maintenanceMarginFraction: 100)
        let signed = PerpsSignedMarket.matching(market, quoteDecimals: 7)

        let rules = try PerpsPlannerMapping.rules(
            market: market,
            signed: signed,
            environment: "mainnet",
            receivedAtUnixMs: 1,
            integrator: Self.noIntegrator
        )

        XCTAssertEqual(rules.scale.quoteDecimals, 7)
        XCTAssertEqual(rules.minNotionalQuote?.int64Value, 100_000_000)
        XCTAssertEqual(rules.minBaseAmount, 2)
    }

    func testALimitAtOrBelowMaintenanceMarginIsLiftedAboveIt() throws {
        let rules = try makeRules(maxLeverage: 200, initialMarginFraction: 500, maintenanceMarginFraction: 100)

        XCTAssertEqual(rules.minInitialMarginBps, 101)
    }

    func testZeroIntegratorAccountDisablesAttributionEvenIfFeesArePresent() throws {
        let rules = try makeRules(
            maxLeverage: 50,
            initialMarginFraction: 500,
            maintenanceMarginFraction: 100,
            integrator: .init(
                integrator_account_index: 0,
                integrator_taker_fee: 900,
                integrator_maker_fee: 700,
                max_perps_taker_fee: 1000,
                max_perps_maker_fee: 800,
                max_spot_taker_fee: 0,
                max_spot_maker_fee: 0,
                approval_ttl_ms: 31_536_000_000
            )
        )

        XCTAssertEqual(rules.integrator.accountIndex, 0)
        XCTAssertEqual(rules.integrator.open.takerFeePpm, 0)
        XCTAssertEqual(rules.integrator.open.makerFeePpm, 0)
    }

    func testTheAccountTierFeeIsOnlyShownNeverPriced() throws {
        let plus = try makeRules(
            maxLeverage: 50,
            initialMarginFraction: 500,
            maintenanceMarginFraction: 100,
            integrator: .init(
                integrator_account_index: 745_796,
                integrator_taker_fee: 900,
                integrator_maker_fee: 900,
                max_perps_taker_fee: 1000,
                max_perps_maker_fee: 1000,
                max_spot_taker_fee: 0,
                max_spot_maker_fee: 0,
                approval_ttl_ms: 31_536_000_000,
                venue_taker_fee: 50,
                venue_maker_fee: 20
            )
        )
        XCTAssertEqual(plus.takerFeePpm, 3)
        XCTAssertEqual(plus.makerFeePpm, 0)
        XCTAssertEqual(plus.effectiveTakerFeePpm(kind: .open), 903)

        XCTAssertEqual(PerpsPlannerMapping.displayedTakerFeePpm(.open, rules: plus, venueTakerFeePpm: 50), 950)
        XCTAssertEqual(PerpsPlannerMapping.displayedTakerFeePpm(.close, rules: plus, venueTakerFeePpm: 50), 950)
        XCTAssertEqual(PerpsPlannerMapping.displayedTakerFeePpm(.open, rules: plus, venueTakerFeePpm: nil), 903)
    }
}

private extension PerpsMarketRulesTests {
    static let noIntegrator = Components.Schemas.Integrator(
        integrator_account_index: 0,
        integrator_taker_fee: 0,
        integrator_maker_fee: 0,
        max_perps_taker_fee: 0,
        max_perps_maker_fee: 0,
        max_spot_taker_fee: 0,
        max_spot_maker_fee: 0,
        approval_ttl_ms: 0
    )

    func makeMarket(
        maxLeverage: Int,
        initialMarginFraction: Int?,
        maintenanceMarginFraction: Int?
    ) -> Components.Schemas.Market {
        Components.Schemas.Market(
            market_index: 1,
            symbol: "BTC",
            status: "active",
            price_decimals: 1,
            size_decimals: 5,
            tick_size: "0.1",
            step_size: "0.00001",
            min_size_base: "0.00002",
            min_size_quote: "10",
            max_leverage: maxLeverage,
            maker_fee_pct: "0",
            taker_fee_pct: "0.00025",
            initial_margin_fraction: initialMarginFraction,
            maintenance_margin_fraction: maintenanceMarginFraction
        )
    }

    func makeRules(
        maxLeverage: Int,
        initialMarginFraction: Int?,
        maintenanceMarginFraction: Int?,
        integrator: Components.Schemas.Integrator = noIntegrator
    ) throws -> PerpsMarketRules {
        try PerpsPlannerMapping.rulesSignedAsServed(
            market: makeMarket(
                maxLeverage: maxLeverage,
                initialMarginFraction: initialMarginFraction,
                maintenanceMarginFraction: maintenanceMarginFraction
            ),
            environment: "mainnet",
            receivedAtUnixMs: 1,
            integrator: integrator
        )
    }
}

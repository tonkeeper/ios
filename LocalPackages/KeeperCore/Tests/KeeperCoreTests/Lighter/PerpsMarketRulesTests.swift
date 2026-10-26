import ChainKit
@testable import KeeperCore
import TKPerpsAPI
import XCTest

final class PerpsMarketRulesTests: XCTestCase {
    func testTheLeverageLimitComesFromMaxLeverageNotTheVenueDefault() throws {
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

    func testWithoutAMaxLeverageTheDefaultFractionIsTheOnlyLimitLeft() throws {
        let rules = try makeRules(maxLeverage: nil, initialMarginFraction: 666, maintenanceMarginFraction: 100)

        XCTAssertEqual(rules.minInitialMarginBps, 666)
    }

    func testALimitAtOrBelowMaintenanceMarginIsLiftedAboveIt() throws {
        let rules = try makeRules(maxLeverage: 200, initialMarginFraction: 500, maintenanceMarginFraction: 100)

        XCTAssertEqual(rules.minInitialMarginBps, 101)
    }

    func testAMarketThatNamesNoLimitAtAllIsRefused() {
        XCTAssertThrowsError(
            try makeRules(maxLeverage: nil, initialMarginFraction: nil, maintenanceMarginFraction: 100)
        )
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
}

private extension PerpsMarketRulesTests {
    func makeRules(
        maxLeverage: Int?,
        initialMarginFraction: Int?,
        maintenanceMarginFraction: Int?,
        integrator: Components.Schemas.Integrator = .init(
            integrator_account_index: 0,
            integrator_taker_fee: 0,
            integrator_maker_fee: 0,
            max_perps_taker_fee: 0,
            max_perps_maker_fee: 0,
            max_spot_taker_fee: 0,
            max_spot_maker_fee: 0,
            approval_ttl_ms: 0
        )
    ) throws -> PerpsMarketRules {
        try PerpsPlannerMapping.rules(
            market: Components.Schemas.Market(
                market_index: 1,
                symbol: "BTC",
                status: "active",
                price_decimals: 1,
                size_decimals: 5,
                tick_size: "0.1",
                step_size: "0.00001",
                min_size_base: "0.00002",
                max_leverage: maxLeverage,
                maker_fee_pct: "0",
                taker_fee_pct: "0.00025",
                initial_margin_fraction: initialMarginFraction,
                maintenance_margin_fraction: maintenanceMarginFraction
            ),
            environment: "mainnet",
            receivedAtUnixMs: 1,
            integrator: integrator
        )
    }
}

import ChainKit
@testable import KeeperCore
import TKPerpsAPI
import XCTest

final class PerpsPlannerSideTests: XCTestCase {
    func testAShortPositionStaysShort() throws {
        let present = try XCTUnwrap(context(position: .short).position as? PerpsPositionState.Present)

        XCTAssertEqual(present.side, PerpsSide.short_)
    }

    func testALongPositionStaysLong() throws {
        let present = try XCTUnwrap(context(position: .long).position as? PerpsPositionState.Present)

        XCTAssertEqual(present.side, PerpsSide.long_)
    }

    func testAnUnknownPositionSideIsRefused() {
        XCTAssertThrowsError(try context(position: .unknown))
    }

    func testAPositionWithoutASideIsRefused() {
        XCTAssertThrowsError(try context(position: nil))
    }

    func testAnOrderSideIsKeptAsSent() throws {
        let resting = try PerpsPlannerMapping.restingOrders([order(side: .short)], rules: makeRules())

        XCTAssertEqual(resting.map(\.side), [PerpsSide.short_])
    }

    func testAnUnknownOrderSideIsRefused() throws {
        let rules = try makeRules()

        XCTAssertThrowsError(try PerpsPlannerMapping.restingOrders(
            [order(side: .short), order(side: .unknown)],
            rules: rules
        ))
    }

    func testAnOrderWithoutASideIsRefused() throws {
        let rules = try makeRules()

        XCTAssertThrowsError(try PerpsPlannerMapping.restingOrders([order(side: nil)], rules: rules))
    }

    func testTheLegsOfAShortPositionCloseLong() throws {
        let resting = try PerpsPlannerMapping.restingOrders(
            autoClose: autoClose(),
            positionSide: .short,
            rules: makeRules()
        )

        XCTAssertEqual(resting.map(\.side), [PerpsSide.long_])
    }

    func testTheLegsOfAPositionWithAnUnknownSideAreRefused() throws {
        let rules = try makeRules()

        XCTAssertThrowsError(try PerpsPlannerMapping.restingOrders(
            autoClose: autoClose(),
            positionSide: .unknown,
            rules: rules
        ))
        XCTAssertThrowsError(try PerpsPlannerMapping.restingOrders(
            autoClose: autoClose(),
            positionSide: nil,
            rules: rules
        ))
    }

    func testAPositionWithoutASizeIsRefused() {
        XCTAssertThrowsError(try context(position: .long, size: nil))
        XCTAssertThrowsError(try context(position: .long, size: ""))
    }

    func testANegativeSizeIsRefused() {
        XCTAssertThrowsError(try context(position: .long, size: "-0.002"))
    }

    func testAPositionKeepsItsMarginSettings() throws {
        let known = try XCTUnwrap(context(position: .long).marginSettings as? PerpsMarginSettings.Known)

        XCTAssertEqual(known.initialMarginBps, 1000)
    }

    func testAFlatMarketLeavesMarginSettingsUnknownWhateverTheScreenSays() throws {
        let isolated = try snapshot(Components.Schemas.TradingScreen(
            open_orders: [],
            leverage: 10,
            margin_mode: .init(value1: .isolated)
        ))
        let emptied = try context(position: .long, size: "0")

        XCTAssertTrue(isolated.marginSettings is PerpsMarginSettings.Unknown)
        XCTAssertTrue(emptied.position is PerpsPositionState.KnownFlat)
        XCTAssertTrue(emptied.marginSettings is PerpsMarginSettings.Unknown)
    }
}

private extension PerpsPlannerSideTests {
    func context(
        position side: Components.Schemas.PositionSide?,
        size: String? = "0.002"
    ) throws -> PerpetualAccountSnapshot {
        try snapshot(Components.Schemas.TradingScreen(
            position: .init(value1: .init(
                market_index: 1,
                symbol: "BTC",
                side: side,
                size: size,
                avg_entry_price: "67000",
                margin_mode: .isolated,
                allocated_margin: "13.4",
                leverage: 10
            )),
            open_orders: []
        ))
    }

    func snapshot(_ screen: Components.Schemas.TradingScreen) throws -> PerpetualAccountSnapshot {
        try PerpsPlannerMapping.context(
            scope: PerpsScope(
                walletId: "wallet",
                venue: PerpsPlannerMapping.venue,
                chainId: 304,
                environment: "mainnet",
                accountIndex: 42,
                keyBindingId: "42/3",
                expectedPublicKey: "key"
            ),
            marketId: 1,
            screen: screen,
            rules: makeRules(),
            receivedAtUnixMs: 1,
            restingOrders: [],
            ordersKnown: true
        )
    }

    func order(side: Components.Schemas.OrderSide?) -> Components.Schemas.Order {
        Components.Schemas.Order(
            order_index: 11,
            client_order_index: 1001,
            side: side,
            _type: .limit,
            category: .open,
            base_size: "0.002",
            price: "60000"
        )
    }

    func autoClose() -> Components.Schemas.PositionAutoClose {
        Components.Schemas.PositionAutoClose(
            take_profit: .init(value1: Components.Schemas.PositionAutoCloseLeg(
                order_index: 281_474_976_712_114,
                client_order_index: 1_756_280_400_123,
                trigger_price: "60000",
                price: "61800",
                order_type: .market,
                valid_to: 1_780_000_000,
                base_size: "0.002"
            )),
            stop_loss: nil
        )
    }

    func makeRules() throws -> PerpsMarketRules {
        try PerpsPlannerMapping.rulesSignedAsServed(
            market: Components.Schemas.Market(
                market_index: 1,
                symbol: "BTC",
                status: "active",
                price_decimals: 1,
                size_decimals: 5,
                tick_size: "0.1",
                step_size: "0.00001",
                min_size_base: "0.00002",
                max_leverage: 50,
                maker_fee_pct: "0",
                taker_fee_pct: "0.00025",
                initial_margin_fraction: 500,
                maintenance_margin_fraction: 100
            ),
            environment: "mainnet",
            receivedAtUnixMs: 1,
            integrator: .init(
                integrator_account_index: 0,
                integrator_taker_fee: 0,
                integrator_maker_fee: 0,
                max_perps_taker_fee: 0,
                max_perps_maker_fee: 0,
                max_spot_taker_fee: 0,
                max_spot_maker_fee: 0,
                approval_ttl_ms: 0
            )
        )
    }
}

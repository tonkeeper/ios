import ChainKit
@testable import KeeperCore
import PerpsModels
import TKPerpsAPI
import XCTest

final class PerpsOpenMinimumMarginTests: XCTestCase {
    func testTheMinimumPricesTheMarginFractionTheWayThePlannerRoundsIt() throws {
        let rules = try PerpsPlannerMapping.rules(
            market: Components.Schemas.Market(
                market_index: 1,
                symbol: "BTC",
                status: "active",
                price_decimals: 1,
                size_decimals: 5,
                tick_size: "0.1",
                step_size: "0.00001",
                min_size_base: "0.001",
                max_leverage: 50,
                maker_fee_pct: "0",
                taker_fee_pct: "0",
                initial_margin_fraction: 200,
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
        let now: Int64 = 1000
        let open = PerpsTradeIntent.Open(
            operationId: "op",
            scope: PerpsScope.companion.review(
                walletId: "wallet",
                venue: "lighter",
                chainId: 304,
                environment: "mainnet",
                accountIndex: 0
            ),
            marketId: 1,
            side: .long_,
            marginBudgetQuote: 0,
            initialMarginBps: PerpsPlannerMapping.initialMarginBps(leverage: 3),
            clientOrderIndex: 1,
            order: PerpsOrderSpec.Limit(limitPrice: 600_000, postOnly: false, orderExpiryUnixMs: now + 86_400_000),
            autoClose: nil
        )
        let snapshot = PerpsPlannerMapping.markSnapshot(
            marketId: 1,
            environment: "mainnet",
            mark: PerpsMarkPrice(price: 600_000, observedAtUnixMs: now),
            receivedAtUnixMs: now
        )

        let minimum = try PerpsPlannerMapping.minimumOpenMarginUsd(
            open,
            rules: rules,
            marketSnapshot: snapshot,
            nowUnixMs: now
        )

        XCTAssertEqual(minimum, 20.004, accuracy: 1e-9)
    }
}

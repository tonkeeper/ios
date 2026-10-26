import ChainKit
@testable import KeeperCore
import PerpsModels
import TKPerpsAPI
import XCTest

final class PerpsMarginChangeLimitsTests: XCTestCase {
    func testReduceKeepsTheUnrealisedLossAndTheBufferAndStopsAtWholeCents() throws {
        let limits = try PerpsPlannerMapping.marginChangeLimits(context: makeLosingLongContext())

        XCTAssertEqual(limits.minUsd, 1)
        XCTAssertEqual(limits.maxReduceUsd, 2.97)
    }
}

private extension PerpsMarginChangeLimitsTests {
    func makeLosingLongContext() throws -> PerpsMarketContext {
        let rules = try PerpsPlannerMapping.rules(
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
        let scope = PerpsScope.companion.review(
            walletId: "wallet",
            venue: "lighter",
            chainId: 304,
            environment: "mainnet",
            accountIndex: 0
        )
        let account = PerpetualAccountSnapshot(
            scope: scope,
            marketId: 1,
            freshness: PerpsFreshness(receivedAtUnixMs: 1, sourceUpdatedAtUnixMs: nil),
            completeness: PerpsContextCompleteness.Complete.shared,
            openEnabled: true,
            availableBalanceQuote: 5_000_000,
            position: PerpsPositionState.Present(
                positionId: "1",
                side: .long_,
                baseAmount: 57,
                entryPrice: 863_419,
                allocatedMarginQuote: 3_984_300,
                liquidationPrice: nil
            ),
            restingOrders: [],
            marginSettings: PerpsMarginSettings.Known(mode: 1, initialMarginBps: 200)
        )
        return PerpsMarketContext(
            walletId: "wallet",
            scope: scope,
            rules: rules,
            accountSnapshot: account,
            marketSnapshot: nil,
            symbol: "BTC",
            leverage: 50,
            limitOrders: [],
            mark: PerpsMarkPrice(price: 863_068, observedAtUnixMs: 1),
            nowUnixMs: 1
        )
    }
}

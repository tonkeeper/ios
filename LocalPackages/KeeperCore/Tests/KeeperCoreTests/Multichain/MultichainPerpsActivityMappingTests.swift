import Foundation
@testable import KeeperCore
import MultichainAPI
import OpenAPIRuntime
import XCTest

final class MultichainPerpsActivityMappingTests: XCTestCase {
    func test_mapsClosedPositionOnTheLighterChain() throws {
        let activity = try XCTUnwrap(MultichainActivity(api: Self.makeActivity(
            activityType: "perps.position_closed",
            chain: "lighter",
            perps: [
                "symbol": "BTC",
                "asset_id": "lighter/mainnet/1",
                "side": "long",
                "reason": "take_profit",
                "account_index": 738_887,
                "settled_at": "2026-09-08T18:47:09.691Z",
            ]
        )))

        XCTAssertEqual(activity.activityType, .perpsPositionClosed)
        XCTAssertNil(activity.fromChain)
        XCTAssertNil(activity.toChain)
        XCTAssertEqual(activity.perps?.symbol, "BTC")
        XCTAssertEqual(activity.perps?.assetId, "lighter/mainnet/1")
        XCTAssertEqual(activity.perps?.side, .long)
        XCTAssertEqual(activity.perps?.closeReason, .takeProfit)
        XCTAssertEqual(activity.perps?.accountIndex, 738_887)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        XCTAssertEqual(
            activity.perps?.settledAt,
            formatter.date(from: "2026-09-08T18:47:09.691Z")
        )
    }

    func test_readsClosedPositionFiguresFromDecimalStrings() throws {
        let perps = try XCTUnwrap(MultichainActivity(api: Self.makeActivity(
            activityType: "perps.position_closed",
            chain: "lighter",
            perps: [
                "symbol": "SOL",
                "asset_id": "lighter/mainnet/market/2",
                "side": "long",
                "reason": "manual",
                "account_index": 747_112,
                "leverage": "2",
                "entry_price": "119.591",
                "close_price": "121.339",
                "size": "0.085",
                "size_usd": "10.313815",
                "result_pct": "2.858516",
                "funding_usd": "-0.001169",
            ]
        ))?.perps)

        XCTAssertEqual(perps.leverage, 2)
        XCTAssertEqual(perps.entryPrice, 119.591)
        XCTAssertEqual(perps.closePrice, 121.339)
        XCTAssertEqual(perps.size, 0.085)
        XCTAssertEqual(perps.sizeUsd, 10.313815)
        XCTAssertEqual(perps.resultPercent, 2.858516)
        XCTAssertEqual(perps.fundingUsd, -0.001169)
        XCTAssertNil(perps.marginUsd)
    }

    func test_readsOpenedPositionMarginAndAcceptsPlainNumbers() throws {
        let perps = try XCTUnwrap(MultichainActivity(api: Self.makeActivity(
            activityType: "perps.position_opened",
            chain: "lighter",
            perps: [
                "symbol": "ETH",
                "asset_id": "lighter/mainnet/market/0",
                "side": "long",
                "leverage": 20,
                "entry_price": 2720.09,
                "margin_usd": "0.992832",
                "size": "not a number",
            ]
        ))?.perps)

        XCTAssertEqual(perps.leverage, 20)
        XCTAssertEqual(perps.entryPrice, 2720.09)
        XCTAssertEqual(perps.marginUsd, 0.992832)
        XCTAssertNil(perps.size)
        XCTAssertNil(perps.closePrice)
        XCTAssertNil(perps.resultPercent)
        XCTAssertNil(perps.fundingUsd)
    }

    func test_readsTheOhmsRewardWithoutPaddingZeros() throws {
        XCTAssertEqual(try reward(["asset": "OHM", "amount": "1000"]), "1000")
        XCTAssertEqual(try reward(["asset": "OHM", "amount": "12.000000"]), "12")
        XCTAssertEqual(try reward(["asset": "OHM", "amount": "1234.56", "boost": "200"]), "1234.56")
    }

    func test_dropsARewardThatIsNotAPositiveOhmsAmount() throws {
        XCTAssertNil(try reward(nil))
        XCTAssertNil(try reward(["asset": "OHM", "amount": "0"]))
        XCTAssertNil(try reward(["asset": "OHM", "amount": "-5"]))
        XCTAssertNil(try reward(["asset": "USDC", "amount": "11"]))
        XCTAssertNil(try reward(["asset": "OHM"]))
    }

    func test_mapsUnknownActivityTypeWithoutDroppingTheRow() throws {
        let activity = try XCTUnwrap(MultichainActivity(api: Self.makeActivity(
            activityType: "perps.something_new",
            chain: "lighter",
            perps: nil
        )))

        XCTAssertEqual(activity.activityType, .unknown)
        XCTAssertNil(activity.perps)
    }

    func test_keepsKnownChainsAndCarriesNoPerpsMeta() throws {
        let activity = try XCTUnwrap(MultichainActivity(api: Self.makeActivity(
            activityType: "send",
            chain: "eth",
            perps: nil
        )))

        XCTAssertEqual(activity.activityType, .send)
        XCTAssertEqual(activity.fromChain, .eth)
        XCTAssertEqual(activity.toChain, .eth)
        XCTAssertNil(activity.perps)
    }

    func test_dropsNonPerpsRowsOnAChainTheAppCannotResolve() throws {
        XCTAssertNil(try MultichainActivity(api: Self.makeActivity(
            activityType: "send",
            chain: "near",
            perps: nil
        )))
    }

    func test_withoutAPrimaryExplorerLink_takesTheFirstLinkTheBackendHas() throws {
        var api = try Self.makeActivity(activityType: "perps.balance_withdrawal", chain: "lighter", perps: nil)
        api.tx_ids = ["lighter:0xabc", "eth:0xdef"]
        api.explorer_urls = [.init(tx_id: "eth:0xdef", chain: .eth, url: "https://eth.blockscout.com/tx/0xdef")]
        let withdrawal = try XCTUnwrap(MultichainActivity(api: api))
        XCTAssertEqual(withdrawal.explorerURL?.absoluteString, "https://eth.blockscout.com/tx/0xdef")
        XCTAssertEqual(withdrawal.explorerTxId, "eth:0xdef")

        api.explorer_url = "https://explorer.example/tx/0xabc"
        let primary = try XCTUnwrap(MultichainActivity(api: api))
        XCTAssertEqual(primary.explorerURL?.absoluteString, "https://explorer.example/tx/0xabc")
        XCTAssertNil(primary.explorerTxId)
    }

    private func reward(_ reward: [String: String]?) throws -> String? {
        var perps: [String: (any Sendable)?] = ["symbol": "BTC", "side": "long"]
        if let reward {
            perps["reward"] = reward
        }
        return try MultichainActivity(api: Self.makeActivity(
            activityType: "perps.position_opened",
            chain: "lighter",
            perps: perps
        ))?.perps?.loyaltyReward
    }

    private static func makeActivity(
        activityType: String,
        chain: String,
        perps: [String: (any Sendable)?]?
    ) throws -> MultichainAPI.Components.Schemas.Activity {
        try MultichainAPI.Components.Schemas.Activity(
            activity_type: activityType,
            status: .confirmed,
            block_time: Date(timeIntervalSince1970: 0),
            from_chain: chain,
            to_chain: chain,
            direction: ._self,
            tx_ids: ["\(chain):0xabc"],
            meta: perps.map {
                try .init(additionalProperties: OpenAPIObjectContainer(unvalidatedValue: ["perps": $0]))
            }
        )
    }
}

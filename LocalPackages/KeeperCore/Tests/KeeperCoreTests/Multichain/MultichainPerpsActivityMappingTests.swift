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
            chain: "sol",
            perps: nil
        )))
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

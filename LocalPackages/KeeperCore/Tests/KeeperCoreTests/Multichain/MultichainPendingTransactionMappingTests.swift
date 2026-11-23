import Foundation
@testable import KeeperCore
import MultichainAPI
import XCTest

final class MultichainPendingTransactionMappingTests: XCTestCase {
    func test_swap_isReportedAsSwapWithBothLegsAndQuoteAttributionInPayload() throws {
        let json = try encoded(
            makeTransaction(
                activityType: .swap(
                    MultichainPendingTransaction.SwapDetails(
                        fromAssetId: "ton/mainnet/coin",
                        toAssetId: "eth/mainnet/coin",
                        fromAddress: "UQ-source",
                        fromAmount: "123456789012345678901234567890",
                        quote: .init(aggregator: "swapsxyz", routeId: "route-id", providerRouteId: "tx-id")
                    )
                )
            )
        )

        XCTAssertEqual(json["activity_type"] as? String, "swap")
        XCTAssertEqual(
            json["payload"] as? [String: String],
            [
                "from_asset_id": "ton/mainnet/coin",
                "to_asset_id": "eth/mainnet/coin",
                "from_address": "UQ-source",
                "from_amount": "123456789012345678901234567890",
                "aggregator": "swapsxyz",
                "route_id": "route-id",
                "provider_route_id": "tx-id",
            ]
        )
    }

    /// A native TON swap is routed by the wallet itself, so there is no quote to attribute it to.
    func test_swap_withoutAQuote_omitsBothAttributionKeys() throws {
        let json = try encoded(
            makeTransaction(
                activityType: .swap(
                    MultichainPendingTransaction.SwapDetails(
                        fromAssetId: "ton/mainnet/coin",
                        toAssetId: "ton/mainnet/jetton/0:abc",
                        fromAddress: "UQ-source",
                        fromAmount: "1000000000"
                    )
                )
            )
        )

        XCTAssertEqual(
            json["payload"] as? [String: String],
            [
                "from_asset_id": "ton/mainnet/coin",
                "to_asset_id": "ton/mainnet/jetton/0:abc",
                "from_address": "UQ-source",
                "from_amount": "1000000000",
            ]
        )
    }

    /// `provider_route_id` is documented as absent for aggregators that expose no route id;
    /// the aggregator itself is still known.
    func test_swap_withAQuoteThatHasNoRouteId_keepsTheAggregator() throws {
        let json = try encoded(
            makeTransaction(
                activityType: .swap(
                    MultichainPendingTransaction.SwapDetails(
                        fromAssetId: "ton/mainnet/coin",
                        toAssetId: "eth/mainnet/coin",
                        quote: .init(aggregator: "omniston", routeId: "route-id")
                    )
                )
            )
        )

        XCTAssertEqual(
            json["payload"] as? [String: String],
            [
                "from_asset_id": "ton/mainnet/coin",
                "to_asset_id": "eth/mainnet/coin",
                "aggregator": "omniston",
                "route_id": "route-id",
            ]
        )
    }

    func test_activityTypesWithoutExtras_areReportedWithoutPayload() throws {
        for activityType: MultichainPendingTransaction.ActivityType in [.send, .stake, .unstake, .contractCall] {
            let json = try encoded(makeTransaction(activityType: activityType))

            XCTAssertEqual(json["activity_type"] as? String, activityType.name)
            XCTAssertNil(json["payload"])
        }
    }
}

private extension MultichainPendingTransactionMappingTests {
    func makeTransaction(
        activityType: MultichainPendingTransaction.ActivityType
    ) -> MultichainPendingTransaction {
        MultichainPendingTransaction(
            walletId: "wallet",
            chain: .eth,
            network: .mainnet,
            txHash: "hash",
            activityType: activityType
        )
    }

    func encoded(_ transaction: MultichainPendingTransaction) throws -> [String: Any] {
        let data = try JSONEncoder().encode(transaction.toAPISchemaPendingTransaction())
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}

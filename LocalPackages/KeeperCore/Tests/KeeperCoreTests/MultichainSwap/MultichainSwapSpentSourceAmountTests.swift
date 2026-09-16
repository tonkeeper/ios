import BigInt
import Foundation
@testable import KeeperCore
import XCTest

final class MultichainSwapSpentSourceAmountTests: XCTestCase {
    /// Captured from a swaps.xyz TON route: the message value carries the traded amount plus the gas
    /// the contracts forward, so it is far above the quoted `source_amount`.
    func test_tonNativeRoute_usesMessageValueInsteadOfQuotedSourceAmount() {
        let route = makeRoute(
            sourceAmount: "300000000",
            payloads: [makeTonPayload(envelope: #"[{"address":"EQC","amount":"580000000","payload":"te6"}]"#)]
        )

        XCTAssertEqual(route.spentSourceAmount(sourceAsset: tonCoin), 580_000_000)
    }

    func test_tonNativeRoute_readsTheOtherSpellingOfTheValueKey() {
        let route = makeRoute(
            sourceAmount: "300000000",
            payloads: [makeTonPayload(envelope: #"[{"to":"EQC","value":"580000000","payload":"te6"}]"#)]
        )

        XCTAssertEqual(route.spentSourceAmount(sourceAsset: tonCoin), 580_000_000)
    }

    func test_tonNativeRoute_sumsEveryMessageInTheEnvelope() {
        let route = makeRoute(
            sourceAmount: "300000000",
            payloads: [makeTonPayload(
                envelope: #"[{"address":"EQC","amount":"580000000","payload":"a"},{"address":"EQD","amount":"20000000","payload":"b"}]"#
            )]
        )

        XCTAssertEqual(route.spentSourceAmount(sourceAsset: tonCoin), 600_000_000)
    }

    /// A jetton route's message value is the TON gas, never the jetton being sold.
    func test_tonJettonRoute_keepsQuotedSourceAmount() {
        let route = makeRoute(
            sourceAmount: "300000000",
            payloads: [makeTonPayload(envelope: #"[{"address":"EQC","amount":"580000000","payload":"te6"}]"#)]
        )

        XCTAssertEqual(
            route.spentSourceAmount(sourceAsset: makeAsset(assetId: "ton/mainnet/jetton/0:abc", decimals: 6)),
            300_000_000
        )
    }

    func test_flexibleCalldata_keepsQuotedSourceAmount() {
        let route = makeRoute(
            sourceAmount: "300000000",
            payloads: [makeTonPayload(
                envelope: #"[{"address":"EQC","amount":"580000000","payload":"te6"}]"#,
                calldataPayloadType: .flex
            )]
        )

        XCTAssertEqual(route.spentSourceAmount(sourceAsset: tonCoin), 300_000_000)
    }

    func test_routeWithoutInlinePayloads_keepsQuotedSourceAmount() {
        let route = makeRoute(sourceAmount: "300000000", payloads: nil)

        XCTAssertEqual(route.spentSourceAmount(sourceAsset: tonCoin), 300_000_000)
    }

    func test_unreadableEnvelope_keepsQuotedSourceAmount() {
        let route = makeRoute(
            sourceAmount: "300000000",
            payloads: [makeTonPayload(envelope: #"[{"address":"EQC","payload":"te6"}]"#)]
        )

        XCTAssertEqual(route.spentSourceAmount(sourceAsset: tonCoin), 300_000_000)
    }

    func test_evmRoute_keepsQuotedSourceAmount() {
        let route = makeRoute(
            sourceAmount: "300000000",
            payloads: [makeTonPayload(envelope: #"[{"address":"EQC","amount":"580000000","payload":"te6"}]"#)]
        )

        XCTAssertEqual(
            route.spentSourceAmount(sourceAsset: makeAsset(assetId: "eth/mainnet/coin", decimals: 18)),
            300_000_000
        )
    }

    func test_routeWithoutQuotedSourceAmount_reportsNothingToCompare() {
        let route = makeRoute(sourceAmount: nil, payloads: nil)

        XCTAssertNil(route.spentSourceAmount(sourceAsset: tonCoin))
    }
}

private extension MultichainSwapSpentSourceAmountTests {
    var tonCoin: MultichainAsset {
        makeAsset(assetId: "ton/mainnet/coin", decimals: 9)
    }

    func makeRoute(
        sourceAmount: String?,
        payloads: [MultichainSwapPreparedPayload]?
    ) -> MultichainSwapRoute {
        MultichainSwapRoute(
            routeId: "route",
            aggregator: MultichainSwapAggregator.swapsXyz.rawValue,
            routeType: "cross_chain_swap",
            sourceAmount: sourceAmount,
            estimatedDestinationAmount: "1",
            minimumDestinationAmount: "1",
            legs: [],
            dateExpire: Date(timeIntervalSince1970: 1000),
            riskLevel: "low",
            payloads: payloads
        )
    }

    func makeTonPayload(
        envelope: String,
        calldataPayloadType: MultichainSwapCalldataPayloadType? = nil
    ) -> MultichainSwapPreparedPayload {
        MultichainSwapPreparedPayload(
            payloadId: "payload",
            kind: "main",
            chainId: "ton/mainnet",
            chainFamily: "TON",
            payloadType: "ton_boc",
            payload: envelope,
            humanSummary: MultichainSwapHumanSummary(
                action: "swap",
                spendAsset: "ton/mainnet/coin",
                spendAmount: "300000000",
                receiveAsset: "ton/mainnet/jetton/0:abc",
                depositAddress: nil
            ),
            validationStatus: "validated",
            dateExpire: Date(timeIntervalSince1970: 1000),
            calldataPayloadType: calldataPayloadType
        )
    }

    func makeAsset(assetId: String, decimals: Int) -> MultichainAsset {
        MultichainAsset(
            asset: MultichainAssetDetails(
                assetId: assetId,
                name: "asset",
                symbol: "AST",
                decimals: decimals,
                image: ""
            ),
            price: MultichainAssetPrice(prices: [:], diff24h: [:], diff7d: [:], diff30d: [:]),
            balance: 0
        )
    }
}

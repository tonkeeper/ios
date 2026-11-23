@testable import KeeperCore
import MultichainAPI
import XCTest

final class MultichainAssetCapabilityMappingTests: XCTestCase {
    func test_mapsKnownCapabilitiesAndDropsUnknownValues() {
        let details = MultichainAssetDetails(api: Self.makeAssetInfo(
            capabilities: ["swap", "onramp", "offramp", "p2p", "perp_deposit", "teleport"]
        ))

        XCTAssertEqual(details.capabilities, [.swap, .onramp, .offramp, .p2p, .perpDeposit])
    }

    func test_absentCapabilitiesMapToEmptySet() {
        let details = MultichainAssetDetails(api: Self.makeAssetInfo(capabilities: nil))

        XCTAssertEqual(details.capabilities, [])
    }

    func test_mapsSwapAggregatorsAndDropsUnknownValues() {
        let details = MultichainAssetDetails(api: Self.makeAssetInfo(
            capabilities: ["swap"],
            swapAggregators: ["omniston", "swapsxyz", "swapkit", "relay"]
        ))

        XCTAssertEqual(details.swapAggregators, [.omniston, .swapsXyz, .swapKit])
    }

    func test_absentSwapAggregatorsMapToNil() {
        let details = MultichainAssetDetails(api: Self.makeAssetInfo(capabilities: ["swap"]))

        XCTAssertNil(details.swapAggregators)
    }

    private static func makeAssetInfo(
        capabilities: [String]?,
        swapAggregators: [String]? = nil
    ) -> MultichainAPI.Components.Schemas.AssetInfo {
        MultichainAPI.Components.Schemas.AssetInfo(
            asset_id: "ton/mainnet/coin",
            name: "Toncoin",
            symbol: "TON",
            decimals: 9,
            image: "",
            verification: .trusted,
            capabilities: capabilities.map {
                .init(capabilities: $0, details: swapAggregators.map { .init(swap: .init(aggregators: $0)) })
            }
        )
    }
}

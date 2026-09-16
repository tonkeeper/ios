@testable import KeeperCore
import MultichainAPI
import XCTest

final class MultichainAssetCapabilityMappingTests: XCTestCase {
    func test_mapsKnownCapabilitiesAndDropsUnknownValues() {
        let details = MultichainAssetDetails(api: Self.makeAssetInfo(
            capabilities: ["swap", "onramp", "offramp", "p2p", "teleport"]
        ))

        XCTAssertEqual(details.capabilities, [.swap, .onramp, .offramp, .p2p])
    }

    func test_absentCapabilitiesMapToEmptySet() {
        let details = MultichainAssetDetails(api: Self.makeAssetInfo(capabilities: nil))

        XCTAssertEqual(details.capabilities, [])
    }

    private static func makeAssetInfo(capabilities: [String]?) -> MultichainAPI.Components.Schemas.AssetInfo {
        MultichainAPI.Components.Schemas.AssetInfo(
            asset_id: "ton/mainnet/coin",
            name: "Toncoin",
            symbol: "TON",
            decimals: 9,
            image: "",
            verification: .trusted,
            capabilities: capabilities.map { .init(capabilities: $0) }
        )
    }
}

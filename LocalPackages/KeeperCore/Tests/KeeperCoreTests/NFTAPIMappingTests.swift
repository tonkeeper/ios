import Foundation
@testable import KeeperCore
import OpenAPIRuntime
import TonAPI
import XCTest

final class NFTAPIMappingTests: XCTestCase {
    func testDecodedMetadataPreservesStringIntegerAndFractionalAttributes() throws {
        let metadata = try JSONDecoder().decode(
            OpenAPIObjectContainer.self,
            from: Data(#"{"attributes":[{"trait_type":"Name","value":"Rare"},{"trait_type":"Level","value":7},{"trait_type":"Rarity","value":0.125},{"trait_type":"Missing","value":null},{"trait_type":"Unsupported","value":true}]}"#.utf8)
        )

        let nft = try makeNFT(metadata: metadata)

        XCTAssertEqual(nft.attributes.map(\.key), ["Name", "Level", "Rarity", "Unsupported"])
        XCTAssertEqual(nft.attributes.map(\.value), ["Rare", "7", "0.125", "-"])
    }

    func testWholeNumberStoredAsDoubleRemainsNumeric() throws {
        let metadata = try OpenAPIObjectContainer(unvalidatedValue: [
            "attributes": [["trait_type": "Level", "value": 7.0]],
        ])

        let nft = try makeNFT(metadata: metadata)

        XCTAssertEqual(nft.attributes.map(\.value), ["7.0"])
    }

    private func makeNFT(metadata: OpenAPIObjectContainer) throws -> NFT {
        try NFT(nftItem: .init(
            address: "0:" + String(repeating: "0", count: 64),
            index: 0,
            verified: false,
            metadata: .init(additionalProperties: metadata),
            approvedBy: .init(value1: [.getgems]),
            trust: .none
        ))
    }
}

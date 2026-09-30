import Foundation
@testable import KeeperCore
import TonSwift
import XCTest

/// The analytics backend keys on the exact string, and nothing in the compiler checks one: the
/// literals below are the contract, so a changed segment or address encoding has to fail here.
final class AssetIdTests: XCTestCase {
    private let jettonAddress = try! Address.parse(
        "0:b113a994b5024a16719f69139328eb759596c38a25f59028b146fecdc3621dfe"
    )

    func testTonShapes() {
        XCTAssertEqual(Token.ton(.ton).assetId(network: .mainnet), "ton/mainnet/coin")
        XCTAssertEqual(
            AssetId.jetton(address: jettonAddress, network: .mainnet),
            "ton/mainnet/jetton/0:b113a994b5024a16719f69139328eb759596c38a25f59028b146fecdc3621dfe"
        )
        XCTAssertEqual(
            AssetId.nft(address: jettonAddress, network: .mainnet),
            "ton/mainnet/nft/0:b113a994b5024a16719f69139328eb759596c38a25f59028b146fecdc3621dfe"
        )
    }

    func testTronShapes() {
        XCTAssertEqual(Token.tron(.trx).assetId(network: .mainnet), "tron/mainnet/coin")
        XCTAssertTrue(
            Token.tron(.usdt).assetId(network: .mainnet).hasPrefix("tron/mainnet/trc20/"),
            Token.tron(.usdt).assetId(network: .mainnet)
        )
    }

    func testJettonTokenReportsTheSameIdAsTheBuilder() {
        XCTAssertEqual(
            Token.ton(.jetton(jettonItem)).assetId(network: .mainnet),
            "ton/mainnet/jetton/0:b113a994b5024a16719f69139328eb759596c38a25f59028b146fecdc3621dfe"
        )
    }

    func testTestnetKeepsTheNetworkSegment() {
        XCTAssertEqual(Token.ton(.ton).assetId(network: .testnet), "ton/testnet/coin")
        XCTAssertEqual(
            AssetId.nft(address: jettonAddress, network: .testnet),
            "ton/testnet/nft/0:b113a994b5024a16719f69139328eb759596c38a25f59028b146fecdc3621dfe"
        )
    }

    func testEveryShapeParsesBack() {
        let ids = [
            Token.ton(.ton).assetId(network: .mainnet),
            Token.tron(.trx).assetId(network: .mainnet),
            Token.tron(.usdt).assetId(network: .mainnet),
            AssetId.jetton(address: jettonAddress, network: .mainnet),
            AssetId.nft(address: jettonAddress, network: .mainnet),
        ]

        for id in ids {
            XCTAssertNotNil(AssetIdComponents(assetId: id), id)
        }
    }
}

private extension AssetIdTests {
    var jettonItem: JettonItem {
        JettonItem(
            jettonInfo: JettonInfo(
                isTransferable: true,
                hasCustomPayload: false,
                address: jettonAddress,
                fractionDigits: 6,
                name: "Tether USD",
                symbol: "USD₮",
                verification: .whitelist,
                imageURL: nil
            ),
            walletAddress: nil
        )
    }
}

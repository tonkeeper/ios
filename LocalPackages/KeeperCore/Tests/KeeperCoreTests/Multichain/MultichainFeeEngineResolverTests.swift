@testable import KeeperCore
import TonSwift
import TronSwift
import XCTest

final class MultichainFeeEngineResolverTests: XCTestCase {
    func testUSDTTRC20UsesTronEngineWithMultichainAddress() {
        let wallet = makeWallet(addresses: [
            .init(chain: .tron, address: "TMultichainTronAddress"),
        ])

        let engine = MultichainFeeEngineResolver().resolve(
            asset: makeAsset(assetId: "tron/mainnet/trc20/\(TronSwift.USDT.address.base58)"),
            wallet: wallet
        )

        XCTAssertEqual(engine, .tronUSDT(tronAddress: "TMultichainTronAddress"))
    }

    func testTONJettonUsesJettonEngine() {
        let wallet = makeWallet(addresses: [
            .init(chain: .ton, address: "EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c"),
        ])

        let engine = MultichainFeeEngineResolver().resolve(
            asset: makeAsset(assetId: "ton/mainnet/jetton/0:jetton-master"),
            wallet: wallet
        )

        XCTAssertEqual(engine, .tonJetton(master: "0:jetton-master"))
    }

    func testNonUSDTTRC20KeepsChainKitEngine() {
        let wallet = makeWallet(addresses: [
            .init(chain: .tron, address: "TMultichainTronAddress"),
        ])

        let engine = MultichainFeeEngineResolver().resolve(
            asset: makeAsset(assetId: "tron/mainnet/trc20/TNonUSDTContract"),
            wallet: wallet
        )

        XCTAssertEqual(engine, .chainKit)
    }
}

private extension MultichainFeeEngineResolverTests {
    func makeWallet(addresses: [MultichainWalletAddress]) -> Wallet {
        Wallet(
            id: "wallet-id",
            identity: .init(
                network: .mainnet,
                kind: .Regular(TonSwift.PublicKey(data: Data(repeating: 1, count: 32)), .v4R2)
            ),
            metaData: .init(
                label: "Test wallet",
                tintColor: .defaultColor,
                icon: .icon(.wallet)
            ),
            setupSettings: .init(isSetupFinished: true),
            batterySettings: .init(),
            multichain: .multichain(
                .init(walletId: "multichain-wallet-id", addresses: addresses)
            )
        )
    }

    func makeAsset(assetId: String) -> MultichainAsset {
        MultichainAsset(
            asset: .init(
                assetId: assetId,
                name: "Test asset",
                symbol: "TEST",
                decimals: 6,
                image: ""
            ),
            price: .init(prices: [:], diff24h: [:], diff7d: [:], diff30d: [:]),
            balance: 0
        )
    }
}

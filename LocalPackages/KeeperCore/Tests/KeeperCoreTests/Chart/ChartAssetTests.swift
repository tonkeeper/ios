@testable import KeeperCore
import TonSwift
import TronSwift
import XCTest

final class ChartAssetTests: XCTestCase {
    func test_initWithToken_whenWalletIsLegacy_usesLegacyIdentifier() {
        XCTAssertEqual(
            ChartAsset(token: .ton(.ton), wallet: makeWallet(isMultichain: false)),
            .legacy(token: TonInfo.symbol)
        )
        XCTAssertEqual(
            ChartAsset(token: .tron(.usdt), wallet: makeWallet(isMultichain: false)),
            .legacy(token: JettonMasterAddress.tonUSDT.toRaw())
        )
        XCTAssertEqual(
            ChartAsset(token: .tron(.trx), wallet: makeWallet(isMultichain: false)),
            .legacy(token: TronSwift.TRX.symbol)
        )
    }

    func test_initWithToken_whenWalletIsMultichain_usesAssetId() {
        XCTAssertEqual(
            ChartAsset(token: .ton(.ton), wallet: makeWallet(isMultichain: true)),
            .multichain(assetId: "ton/mainnet/coin")
        )
        XCTAssertEqual(
            ChartAsset(token: .tron(.usdt), wallet: makeWallet(isMultichain: true)),
            .multichain(assetId: "tron/mainnet/trc20/\(TronSwift.USDT.address.base58)")
        )
    }

    func test_initWithToken_whenWalletIsTestnetMultichain_usesTestnetAssetId() {
        XCTAssertEqual(
            ChartAsset(
                token: .ton(.ton),
                wallet: makeWallet(isMultichain: true, network: .testnet)
            ),
            .multichain(assetId: "ton/testnet/coin")
        )
    }

    func test_initWithAssetId_whenWalletIsMultichain_keepsAssetId() {
        XCTAssertEqual(
            ChartAsset(assetId: "ton/mainnet/coin", wallet: makeWallet(isMultichain: true)),
            .multichain(assetId: "ton/mainnet/coin")
        )
    }

    func test_initWithAssetId_whenWalletIsLegacy_resolvesLegacyIdentifier() {
        XCTAssertEqual(
            ChartAsset(assetId: "ton/mainnet/coin", wallet: makeWallet(isMultichain: false)),
            .legacy(token: TonInfo.symbol)
        )
        XCTAssertEqual(
            ChartAsset(
                assetId: "ton/mainnet/jetton/0:jetton-address",
                wallet: makeWallet(isMultichain: false)
            ),
            .legacy(token: "0:jetton-address")
        )
        XCTAssertEqual(
            ChartAsset(assetId: "tron/mainnet/coin", wallet: makeWallet(isMultichain: false)),
            .legacy(token: TronSwift.TRX.symbol)
        )
    }

    func test_initWithAssetId_whenWalletIsLegacyAndAssetIsNotChartable_returnsNil() {
        XCTAssertNil(
            ChartAsset(assetId: "not-an-asset-id", wallet: makeWallet(isMultichain: false))
        )
    }

    func test_cacheToken_isScopedByMode() {
        XCTAssertNotEqual(
            ChartAsset.legacy(token: "identifier").cacheToken,
            ChartAsset.multichain(assetId: "identifier").cacheToken
        )
    }
}

private extension ChartAssetTests {
    func makeWallet(isMultichain: Bool, network: Network = .mainnet) -> Wallet {
        let publicKeyData = Data("chart-asset-tests-public-key".utf8) + Data(repeating: 0, count: 32)
        let publicKey = TonSwift.PublicKey(data: Data(publicKeyData.prefix(32)))
        return Wallet(
            id: "chart-asset-tests",
            identity: WalletIdentity(network: network, kind: .Regular(publicKey, .v4R2)),
            metaData: WalletMetaData(label: "Chart Asset Tests", tintColor: .SteelGray, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings(),
            multichain: isMultichain
                ? .multichain(
                    MultichainWalletState(
                        walletId: "chart-asset-tests-multichain-id",
                        addresses: [
                            MultichainWalletAddress(
                                chain: .ton,
                                address: "chart-asset-tests-ton-address",
                                type: .tonV4R2
                            ),
                        ]
                    )
                )
                : nil
        )
    }
}

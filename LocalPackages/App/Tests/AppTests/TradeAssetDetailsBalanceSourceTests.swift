@testable import App
import Foundation
@testable import KeeperCore
import TonSwift
import TronSwift
import XCTest

final class TradeAssetDetailsBalanceSourceTests: XCTestCase {
    func test_tronUsdtOnMultichainWallet_usesMultichainProvider() {
        let source = makeSource(
            assetId: "tron/mainnet/trc20/\(TronSwift.USDT.address.base58)",
            wallet: makeWallet(multichain: .multichain(makeMultichainState()))
        )

        XCTAssertTrue(source.usesMultichainProvider)
    }

    func test_tronUsdtOnLegacyWallet_usesConvertedBalanceStore() {
        let source = makeSource(
            assetId: "tron/mainnet/trc20/\(TronSwift.USDT.address.base58)",
            wallet: makeWallet(multichain: .unavailable)
        )

        XCTAssertFalse(source.usesMultichainProvider)
    }

    func test_trxOnMultichainWallet_usesMultichainProvider() {
        let source = makeSource(
            assetId: "tron/mainnet/coin",
            wallet: makeWallet(multichain: .multichain(makeMultichainState()))
        )

        XCTAssertTrue(source.usesMultichainProvider)
    }

    func test_trxOnLegacyWallet_usesConvertedBalanceStore() {
        let source = makeSource(
            assetId: "tron/mainnet/coin",
            wallet: makeWallet(multichain: .unavailable)
        )

        XCTAssertFalse(source.usesMultichainProvider)
    }

    func test_tonOnMultichainWallet_usesConvertedBalanceStore() {
        let source = makeSource(
            assetId: "ton/mainnet/coin",
            wallet: makeWallet(multichain: .multichain(makeMultichainState()))
        )

        XCTAssertFalse(source.usesMultichainProvider)
    }

    func test_jettonOnMultichainWallet_usesConvertedBalanceStore() {
        let source = makeSource(
            assetId: "ton/mainnet/jetton/\(JettonMasterAddress.tonUSDT.toRaw())",
            wallet: makeWallet(multichain: .multichain(makeMultichainState()))
        )

        XCTAssertFalse(source.usesMultichainProvider)
    }

    func test_assetWithoutLegacyToken_usesMultichainProvider() {
        let source = makeSource(
            assetId: "eth/mainnet/erc20/0xdac17f958d2ee523a2206206994597c13d831ec7",
            wallet: makeWallet(multichain: .multichain(makeMultichainState()))
        )

        XCTAssertTrue(source.usesMultichainProvider)
    }
}

private extension TradeAssetDetailsBalanceSourceTests {
    func makeSource(assetId: String, wallet: Wallet) -> TradeAssetDetailsBalanceSource {
        TradeAssetDetailsBalanceSource(
            typedAssetId: TradingAssetToken(assetId: assetId),
            wallet: wallet
        )
    }

    func makeMultichainState() -> MultichainWalletState {
        MultichainWalletState(
            walletId: "multichain",
            addresses: [
                MultichainWalletAddress(chain: .tron, address: "TWS1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"),
            ]
        )
    }

    func makeWallet(multichain: MultichainWallet?) -> Wallet {
        Wallet(
            id: "wallet",
            identity: WalletIdentity(
                network: .mainnet,
                kind: .Regular(
                    PublicKey(data: Data(repeating: 0x01, count: 32)),
                    .v4R2
                )
            ),
            metaData: WalletMetaData(
                label: "Test wallet",
                tintColor: .defaultColor,
                icon: .icon(.wallet)
            ),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            batterySettings: BatterySettings(),
            multichain: multichain
        )
    }
}

private extension TradeAssetDetailsBalanceSource {
    var usesMultichainProvider: Bool {
        switch self {
        case .multichain:
            true
        case .legacyStore:
            false
        }
    }
}

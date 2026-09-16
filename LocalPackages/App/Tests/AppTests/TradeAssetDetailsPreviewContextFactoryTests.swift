@testable import App
import Foundation
@testable import KeeperCore
import TonSwift
import TronSwift
import XCTest

final class TradeAssetDetailsPreviewContextFactoryTests: XCTestCase {
    func test_makeTonPreviewContext_usesWalletNetworkAndCryptoCategory() throws {
        let wallet = try makeWallet(id: "ton-testnet-wallet", network: .testnet)

        let preview = AssetIdResolver
            .tonPreviewContext(
                wallet: wallet
            )

        XCTAssertEqual(preview.assetID, "ton/testnet/coin")
        XCTAssertEqual(preview.assetCategory, .tokens)
        XCTAssertEqual(preview.title, TonInfo.name)
        XCTAssertNil(preview.imageURL)
        XCTAssertEqual(preview.isUnverified, false)
        XCTAssertNil(AssetIdResolver.tag(for: preview.assetID, multichainEnabled: false))
        XCTAssertNil(AssetIdResolver.chain(for: preview.assetID, multichainEnabled: false))
    }

    func test_makeJettonPreviewContext_usesJettonAddressAndImage() throws {
        let wallet = try makeWallet(id: "jetton-wallet", network: .mainnet)
        let imageURL = try XCTUnwrap(URL(string: "https://example.com/jetton.png"))
        let jettonItem = JettonItem(
            jettonInfo: JettonInfo(
                isTransferable: true,
                hasCustomPayload: false,
                address: JettonMasterAddress.tonUSDT,
                fractionDigits: 6,
                name: "Tether USD",
                symbol: "USDT",
                verification: .whitelist,
                imageURL: imageURL
            ),
            walletAddress: nil
        )

        let preview = AssetIdResolver
            .jettonPreviewContext(
                wallet: wallet,
                jettonItem: jettonItem
            )

        XCTAssertEqual(preview.assetID, "ton/mainnet/jetton/\(JettonMasterAddress.tonUSDT.toRaw())")
        XCTAssertEqual(preview.assetCategory, .tokens)
        XCTAssertEqual(preview.title, "Tether USD")
        XCTAssertEqual(preview.imageURL, imageURL)
        XCTAssertEqual(preview.isUnverified, false)
        XCTAssertEqual(
            AssetIdResolver.tag(for: preview.assetID, multichainEnabled: false),
            TonInfo.symbol
        )
        XCTAssertEqual(AssetIdResolver.chain(for: preview.assetID, multichainEnabled: false), .ton)
    }

    func test_makeJettonPreviewContext_usesTitleFallbackWhenSymbolMissing() throws {
        let wallet = try makeWallet(id: "jetton-title-fallback", network: .mainnet)
        let jettonItem = JettonItem(
            jettonInfo: JettonInfo(
                isTransferable: true,
                hasCustomPayload: false,
                address: JettonMasterAddress.USDe,
                fractionDigits: 6,
                name: "My Jetton",
                symbol: nil,
                verification: .whitelist,
                imageURL: nil
            ),
            walletAddress: nil
        )

        let preview = AssetIdResolver
            .jettonPreviewContext(
                wallet: wallet,
                jettonItem: jettonItem
            )

        XCTAssertEqual(preview.isUnverified, false)
        XCTAssertNil(AssetIdResolver.tag(for: preview.assetID, multichainEnabled: false))
        XCTAssertNil(AssetIdResolver.chain(for: preview.assetID, multichainEnabled: false))
    }

    func test_makeJettonPreviewContext_marksUnverifiedJetton() throws {
        let wallet = try makeWallet(id: "unverified-jetton-wallet", network: .mainnet)
        let jettonItem = JettonItem(
            jettonInfo: JettonInfo(
                isTransferable: true,
                hasCustomPayload: false,
                address: JettonMasterAddress.USDe,
                fractionDigits: 6,
                name: "Unverified Jetton",
                symbol: "JET",
                verification: .none,
                imageURL: nil
            ),
            walletAddress: nil
        )

        let preview = AssetIdResolver
            .jettonPreviewContext(
                wallet: wallet,
                jettonItem: jettonItem
            )

        XCTAssertEqual(preview.isUnverified, true)
    }

    func test_makeUsdtTrc20PreviewContext_usesTronUsdtContractAddressAndSymbol() throws {
        let wallet = try makeWallet(id: "usdt-trc20-wallet", network: .mainnet)
        let walletTron = makeWalletTron()

        let preview = AssetIdResolver
            .usdtTrc20PreviewContext(
                wallet: wallet,
                walletTron: walletTron
            )

        XCTAssertEqual(preview.assetID, "tron/mainnet/trc20/\(TronSwift.USDT.address.base58)")
        XCTAssertEqual(preview.assetCategory, .tokens)
        XCTAssertEqual(preview.title, TronSwift.USDT.name)
        XCTAssertNil(preview.imageURL)
        XCTAssertEqual(preview.isUnverified, false)
        XCTAssertEqual(
            AssetIdResolver.tag(for: preview.assetID, multichainEnabled: false),
            TronSwift.USDT.tag
        )
        XCTAssertEqual(AssetIdResolver.chain(for: preview.assetID, multichainEnabled: false), .tron)
    }

    func test_makeTrxPreviewContext_usesTronCoinIdentifier() throws {
        let wallet = try makeWallet(id: "trx-wallet", network: .mainnet)
        let walletTron = makeWalletTron()

        let preview = AssetIdResolver
            .trxPreviewContext(
                wallet: wallet,
                walletTron: walletTron
            )

        XCTAssertEqual(preview.assetID, "tron/mainnet/coin")
        XCTAssertEqual(preview.assetCategory, .tokens)
        XCTAssertEqual(preview.title, TronSwift.TRX.name)
        XCTAssertEqual(preview.symbol, TronSwift.TRX.symbol)
        XCTAssertNil(preview.imageURL)
        XCTAssertEqual(preview.isUnverified, false)
    }
}

private extension TradeAssetDetailsPreviewContextFactoryTests {
    func makeWallet(
        id: String,
        network: Network
    ) throws -> Wallet {
        let raw = Data((id + "-public-key").utf8)
        let padded = raw + Data(repeating: 0, count: max(0, 32 - raw.count))
        let publicKey = TonSwift.PublicKey(data: Data(padded.prefix(32)))

        return Wallet(
            id: id,
            identity: WalletIdentity(network: network, kind: .Regular(publicKey, .v4R2)),
            metaData: WalletMetaData(label: id, tintColor: .SteelGray, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings()
        )
    }

    func makeWalletTron() -> WalletTron {
        WalletTron(
            publicKey: TronSwift.PublicKey(data: Data(repeating: 1, count: 33)),
            address: TronSwift.USDT.address
        )
    }
}

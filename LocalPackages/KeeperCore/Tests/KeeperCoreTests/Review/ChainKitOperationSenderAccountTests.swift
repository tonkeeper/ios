import ChainKit
@testable import KeeperCore
import KeeperCoreSensitive
import TonSwift
import XCTest

final class ChainKitOperationSenderAccountTests: XCTestCase {
    private let evmAddress = "0x9858EfFD232B4033E47d90003D41EC34EcaEda94"
    private let evmKey = MultichainPublicKey(defaultHex: "0x0237b0bb7a8288d38ed49a524b5dc98cff3eb5ca824c9f9dc0dfdb3d9cd600f299", segWit: "")
    private let usdtId = "eth/mainnet/erc20/0xdac17f958d2ee523a2206206994597c13d831ec7"

    func test_aCoinAccountHoldsTheChainsCoinWithTheStoredKey() throws {
        let account = try ChainKitOperationSender.account(
            of: MultichainWalletAddress(chain: .eth, address: evmAddress, publicKey: evmKey),
            asset: nil
        )

        XCTAssertEqual(account.chain.id, ChainEthereumMainnet.shared.id)
        XCTAssertEqual(account.asset.id, ChainEthereumMainnet.shared.toAsset().id)
        XCTAssertEqual(account.addressDisplay.lowercased(), evmAddress.lowercased())
        XCTAssertEqual(account.publicKey?.defaultHex, evmKey.defaultHex)
        XCTAssertTrue(account.derivation is DerivationDefaultPath)
    }

    func test_aTokenAccountHoldsTheToken() throws {
        let usdt = try XCTUnwrap(AssetCompanion.shared.fromString(assetId: usdtId, name: "Tether USD", symbol: "USDT", decimals: 6))

        let account = try ChainKitOperationSender.account(
            of: MultichainWalletAddress(chain: .eth, address: evmAddress, publicKey: evmKey),
            asset: usdt
        )

        XCTAssertEqual(account.asset.id, usdtId)
        XCTAssertEqual(account.chain.id, ChainEthereumMainnet.shared.id)
        XCTAssertEqual(account.publicKey?.defaultHex, evmKey.defaultHex)
    }

    func test_aTokenOfAnotherChainIsRefused() throws {
        let tronUSDT = try XCTUnwrap(AssetCompanion.shared.fromString(
            assetId: "tron/mainnet/trc20/TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t",
            name: "Tether USD",
            symbol: "USDT",
            decimals: 6
        ))

        XCTAssertThrowsError(try ChainKitOperationSender.account(
            of: MultichainWalletAddress(chain: .eth, address: evmAddress),
            asset: tronUSDT
        )) { error in
            XCTAssertEqual(error as? ChainKitOperationError, .unsupportedAccount("eth"))
        }
    }

    func test_anAddressWithoutAStoredKeyGivesAnAccountWithoutOne() throws {
        let account = try ChainKitOperationSender.account(
            of: MultichainWalletAddress(chain: .eth, address: evmAddress),
            asset: nil
        )

        XCTAssertNil(account.publicKey)
        XCTAssertEqual(account.addressDisplay.lowercased(), evmAddress.lowercased())
    }

    func test_aLegacyWalletWithoutAMultichainStateHasAccountsForItsTonAndTronAddresses() throws {
        let wallet = try legacyWallet()
        XCTAssertNil(wallet.multichainWalletState)
        let swapWallet = try XCTUnwrap(wallet.legacySwapWallet)
        let ton = try XCTUnwrap(swapWallet.walletAddress(for: .ton))
        let tron = try XCTUnwrap(swapWallet.walletAddress(for: .tron))

        let tonAccount = try ChainKitOperationSender.account(of: ton, asset: nil)
        let tronAccount = try ChainKitOperationSender.account(of: tron, asset: nil)

        XCTAssertEqual(tonAccount.chain.id, ChainTonMainnet.shared.id)
        XCTAssertEqual(tonAccount.address.type, .tonv4r2)
        XCTAssertEqual(tonAccount.publicKey?.defaultHex, ton.publicKey?.defaultHex)
        XCTAssertEqual(tronAccount.chain.id, ChainTronMainnet.shared.id)
        XCTAssertEqual(tronAccount.addressDisplay, try XCTUnwrap(wallet.tron).address.base58)
        XCTAssertNil(tronAccount.publicKey)
    }

    /// A TRON send's instant fee leaves from the wallet's own TON address, which only a multichain
    /// wallet's state names.
    func test_theTonAccountOfALegacyWalletIsItsOwnAddress() throws {
        let wallet = try legacyWallet()
        let ton = try XCTUnwrap(wallet.legacySwapWallet?.walletAddress(for: .ton))

        let account = try ChainKitOperationSender.tonAccount(of: wallet)

        XCTAssertEqual(account.addressDisplay, try ChainKitOperationSender.account(of: ton, asset: nil).addressDisplay)
        XCTAssertEqual(account.publicKey?.defaultHex, ton.publicKey?.defaultHex)
        XCTAssertEqual(account.asset.id, ChainTonMainnet.shared.toAsset().id)
    }

    func test_theTonAccountOfAMultichainWalletIsTheOneItsStateNames() throws {
        let ton = MultichainWalletAddress(
            chain: .ton,
            address: "UQBcmqkZxhc81WNeFFzq9ZX6qBlP28B-MuYeSxpS_-YMIDNl",
            type: .tonV4R2,
            publicKey: MultichainPublicKey(defaultHex: "0x" + String(repeating: "07", count: 32), segWit: "")
        )
        let wallet = Wallet(
            id: "multichain-wallet",
            identity: WalletIdentity(network: .mainnet, kind: .Regular(TonSwift.PublicKey(data: Data(repeating: 7, count: 32)), .v4R2)),
            metaData: WalletMetaData(label: "multichain", tintColor: .SteelGray, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings(),
            multichain: .multichain(MultichainWalletState(walletId: "multichain", addresses: [ton]))
        )

        let account = try ChainKitOperationSender.tonAccount(of: wallet)

        XCTAssertEqual(account.addressDisplay, try ChainKitOperationSender.account(of: ton, asset: nil).addressDisplay)
        XCTAssertEqual(account.publicKey?.defaultHex, ton.publicKey?.defaultHex)
    }

    func test_anAddressTheChainCannotReadIsRefused() {
        XCTAssertThrowsError(try ChainKitOperationSender.account(
            of: MultichainWalletAddress(chain: .tron, address: evmAddress),
            asset: nil
        )) { error in
            XCTAssertEqual(error as? ChainKitOperationError, .unsupportedAccount("tron"))
        }
    }

    private func legacyWallet() throws -> Wallet {
        let words = [
            "business", "thunder", "episode", "arena",
            "tray", "twelve", "humble", "asthma",
            "uphold", "pumpkin", "crunch", "fortune",
        ]
        let keyPair = try CoreMnemonic(mnemonicWords: words, type: .ton).toKeyPair()
        return Wallet(
            id: "legacy-wallet",
            identity: WalletIdentity(network: .mainnet, kind: .Regular(keyPair.publicKey, .v4R2)),
            metaData: WalletMetaData(label: "legacy", tintColor: .SteelGray, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings(),
            tron: WalletTron(tonMnemonic: words)
        )
    }
}

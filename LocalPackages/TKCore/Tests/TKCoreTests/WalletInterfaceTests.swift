import Foundation
@testable import KeeperCore
@testable import TKCore
import TKServices
import TonSwift
import XCTest

final class WalletInterfaceTests: XCTestCase {
    func test_telegramContractMapsToWalletTg() {
        XCTAssertEqual(WalletContractVersion.walletTg.asWalletInterface, .wallettg)
        XCTAssertEqual(WalletInterface.wallettg.rawValue, "walletTg")
    }

    func test_telegramWalletOpenSendsWalletTg() {
        let wallet = makeWallet(kind: .Regular(publicKey, .walletTg))

        XCTAssertEqual(WalletOpen(wallet: wallet).walletInterface, .wallettg)
    }

    func test_telegramWalletTonTransactionSendsWalletTg() {
        let wallet = makeWallet(kind: .Regular(publicKey, .walletTg))
        let tonAsset = KeeperCore.Token.ton(.ton).assetId(network: .mainnet)

        XCTAssertEqual(wallet.transactionInterface(for: tonAsset), .wallettg)
    }

    func test_watchOnlyWalletOpenSendsItsResolvedInterface() {
        XCTAssertEqual(WalletOpen(wallet: makeWallet(kind: .Watchonly(watchedAddress, .walletTg))).walletInterface, .wallettg)
        XCTAssertEqual(WalletOpen(wallet: makeWallet(kind: .Watchonly(watchedAddress, .v4R2))).walletInterface, .v4r2)
    }

    func test_watchOnlyWalletOfUnknownContractOpensWithoutInterface() {
        let wallet = makeWallet(kind: .Watchonly(watchedAddress))

        XCTAssertNil(WalletOpen(wallet: wallet).walletInterface)
    }

    func test_multichainWalletOpensWithoutInterface() {
        let wallet = makeWallet(
            kind: .Regular(publicKey, .v5R1),
            multichain: .multichain(
                MultichainWalletState(
                    walletId: "wallet",
                    addresses: [MultichainWalletAddress(chain: .ton, address: "ton-address")]
                )
            )
        )

        XCTAssertEqual(WalletOpen(wallet: wallet).walletMode, .multi)
        XCTAssertNil(WalletOpen(wallet: wallet).walletInterface)
    }
}

private extension WalletInterfaceTests {
    var publicKey: TonSwift.PublicKey {
        TonSwift.PublicKey(data: Data(repeating: 1, count: 32))
    }

    var watchedAddress: ResolvableAddress {
        .Resolved(Address(workchain: 0, hash: Data(repeating: 1, count: 32)))
    }

    func makeWallet(kind: WalletKind, multichain: MultichainWallet? = nil) -> Wallet {
        Wallet(
            id: "wallet",
            identity: WalletIdentity(network: .mainnet, kind: kind),
            metaData: WalletMetaData(label: "Wallet", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings(),
            multichain: multichain
        )
    }
}

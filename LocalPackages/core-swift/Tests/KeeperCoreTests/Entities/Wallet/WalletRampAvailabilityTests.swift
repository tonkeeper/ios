@testable import KeeperCore
import TonSwift
import XCTest

final class WalletRampAvailabilityTests: XCTestCase {
    func test_testnet_wallet_hides_cash_or_crypto_options() {
        let wallet = makeWallet(network: .testnet, kind: .Regular(publicKey, .v4R2))

        XCTAssertFalse(wallet.isRampCashOrCryptoAvailable)
        XCTAssertFalse(wallet.isRampTRC20Available)
    }

    func test_watch_only_wallet_hides_cash_or_crypto_options() {
        let wallet = makeWallet(network: .mainnet, kind: .Watchonly(.Resolved(tonAddress)))

        XCTAssertFalse(wallet.isRampCashOrCryptoAvailable)
        XCTAssertFalse(wallet.isSendEnable)
        XCTAssertTrue(wallet.isReceiveEnable)
    }

    func test_hardware_and_signer_wallets_keep_cash_or_crypto_options_but_hide_trc20() {
        let signer = makeWallet(network: .mainnet, kind: .Signer(publicKey, .v4R2))
        let ledger = makeWallet(
            network: .mainnet,
            kind: .Ledger(
                publicKey,
                .v4R2,
                .init(deviceId: "ledger-device", deviceModel: "Nano X", accountIndex: 0)
            )
        )
        let keystone = makeWallet(network: .mainnet, kind: .Keystone(publicKey, nil, nil, .v4R2))

        XCTAssertFalse(signer.isRampTRC20Available)
        XCTAssertFalse(ledger.isRampTRC20Available)
        XCTAssertFalse(keystone.isRampTRC20Available)
        XCTAssertTrue(signer.isRampCashOrCryptoAvailable)
        XCTAssertTrue(ledger.isRampCashOrCryptoAvailable)
        XCTAssertTrue(keystone.isRampCashOrCryptoAvailable)
    }
}

private extension WalletRampAvailabilityTests {
    var publicKey: TonSwift.PublicKey {
        TonSwift.PublicKey(data: Data(repeating: 0x01, count: 32))
    }

    var tonAddress: TonSwift.Address {
        try! TonSwift.Address.parse("EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c")
    }

    func makeWallet(network: Network, kind: WalletKind) -> Wallet {
        Wallet(
            id: UUID().uuidString,
            identity: .init(network: network, kind: kind),
            metaData: .init(
                label: "Test wallet",
                tintColor: .defaultColor,
                icon: .icon(.wallet)
            ),
            setupSettings: .init(isSetupFinished: true),
            batterySettings: .init()
        )
    }
}

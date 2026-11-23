import ChainKit
import Foundation
@testable import KeeperCore
import KeeperCoreSensitive
import TonSwift
import TweetNacl
import XCTest

final class LegacyBatteryMigrationTests: XCTestCase {
    func test_proofForAlreadyMultichainWalletIsSignedByItsLegacyTonKey() throws {
        let wallet = try migrationWallet()
        let migration = try XCTUnwrap(LegacyBatteryMigration(wallet: wallet, mnemonic: migrationMnemonic))
        let keyPair = try migrationMnemonic.toKeyPair()
        let message = try XCTUnwrap(BatteryMigrationProof.message(walletId: XCTUnwrap(wallet.multichainWalletId), publicKey: keyPair.publicKey.data))
        let signature = try XCTUnwrap(Data(strictHex: migration.proof.signature))

        XCTAssertTrue(try NaclSign.signDetachedVerify(message: message, sig: signature, publicKey: keyPair.publicKey.data))
        XCTAssertTrue(migration.matches(wallet))
    }

    func test_sourceSnapshotKeepsLegacyIdentityAndNeverUsesWalletIdAuth() throws {
        let wallet = try migrationWallet()
        let source = LegacyBatteryMigration.sourceWallet(from: wallet)

        XCTAssertNil(source.multichain)
        XCTAssertEqual(source.identity, wallet.identity)
        XCTAssertEqual(try source.address, try wallet.address)
        XCTAssertEqual(source.id, wallet.id)
    }

    func test_sourceKeyAndDestinationScopeMustMatch() throws {
        let migration = try XCTUnwrap(LegacyBatteryMigration(wallet: migrationWallet(), mnemonic: migrationMnemonic))

        XCTAssertFalse(try migration.matches(migrationWallet(backendId: "another-wallet")))
        XCTAssertFalse(try migration.matches(migrationWallet(publicKey: TonSwift.PublicKey(data: Data(repeating: 7, count: 32)))))
        XCTAssertTrue(try migration.matches(migrationWallet(id: "reimported", version: .v5R1)))
    }

    func test_wrongMnemonicCannotAuthorizeTheLegacyBalance() throws {
        let wallet = try migrationWallet(publicKey: TonSwift.PublicKey(data: Data(repeating: 7, count: 32)))

        XCTAssertThrowsError(try LegacyBatteryMigration(wallet: wallet, mnemonic: migrationMnemonic))
    }

    func test_destinationMustBelongToTheSameMnemonicBeforeSigning() throws {
        let wallet = try migrationWallet(backendId: "another-wallet")

        XCTAssertThrowsError(try LegacyBatteryMigration(wallet: wallet, mnemonic: migrationMnemonic))
    }

    func test_onlyRegularMainnetBip39WalletsArePrepared() throws {
        XCTAssertNil(try LegacyBatteryMigration(wallet: migrationWallet(network: .testnet), mnemonic: migrationMnemonic))
        XCTAssertNil(try LegacyBatteryMigration(wallet: migrationWallet(isMultichain: false), mnemonic: migrationMnemonic))
        XCTAssertNil(try LegacyBatteryMigration(wallet: migrationWallet(), mnemonic: CoreMnemonic(mnemonicWords: migrationMnemonic.mnemonicWords, type: .ton)))
    }
}

let migrationMnemonic = CoreMnemonic(mnemonicWords: Array(repeating: "abandon", count: 11) + ["about"], type: .bip39)

func migrationWallet(
    id: String = "local-wallet",
    backendId: String? = nil,
    isMultichain: Bool = true,
    network: KeeperCore.Network = .mainnet,
    version: WalletContractVersion = .v4R2,
    publicKey: TonSwift.PublicKey? = nil,
    syncState: MultichainWalletSyncState = .synced
) throws -> Wallet {
    let publicKey = try publicKey ?? migrationMnemonic.toKeyPair().publicKey
    let backendId = try backendId ?? CryptoWallet.Companion.shared.fromMnemonic(mnemonic_: migrationMnemonic.mnemonicWords.joined(separator: " ")).walletIdV2()
    return Wallet(
        id: id,
        identity: WalletIdentity(network: network, kind: .Regular(publicKey, version)),
        metaData: WalletMetaData(label: "Existing", tintColor: .SteelGray, icon: .icon(.wallet)),
        setupSettings: WalletSetupSettings(),
        batterySettings: BatterySettings(),
        multichain: isMultichain ? .multichain(.init(walletId: backendId, addresses: [.init(chain: .eth, address: "0xexisting")], syncState: syncState)) : nil
    )
}

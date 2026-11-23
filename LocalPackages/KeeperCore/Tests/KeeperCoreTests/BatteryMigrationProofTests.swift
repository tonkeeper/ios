import Foundation
@testable import KeeperCore
import KeeperCoreComponents
import TonSwift
import TweetNacl
import XCTest

final class BatteryMigrationProofTests: XCTestCase {
    private let walletId = "aia4kzm6zmtrdhv3iqy3knmnjaxoqy54migq"

    func test_message_lengthPrefixesTheDomainTheWalletIdAndThePublicKey() throws {
        let publicKey = Data(repeating: 7, count: 32)

        let message = try XCTUnwrap(BatteryMigrationProof.message(walletId: walletId, publicKey: publicKey))

        XCTAssertEqual(
            message,
            Data([25]) + Data("keeper.battery.migrate.v1".utf8)
                + Data([36]) + Data(walletId.utf8)
                + Data([32]) + publicKey
        )
    }

    func test_proof_isTheOldKeysSignatureOfTheDestinationWalletId() throws {
        let nacl = try NaclSign.KeyPair.keyPair(fromSeed: Data(repeating: 3, count: 32))
        let keyPair = TonSwift.KeyPair(
            publicKey: TonSwift.PublicKey(data: nacl.publicKey),
            privateKey: TonSwift.PrivateKey(data: nacl.secretKey)
        )

        let proof = try XCTUnwrap(
            BatteryMigrationProof(destinationWallet: makeWallet(walletId: walletId), keyPair: keyPair)
        )

        let message = try XCTUnwrap(BatteryMigrationProof.message(walletId: walletId, publicKey: nacl.publicKey))
        let signature = try XCTUnwrap(Data(strictHex: proof.signature))
        XCTAssertEqual(signature.count, 64)
        XCTAssertTrue(try NaclSign.signDetachedVerify(message: message, sig: signature, publicKey: nacl.publicKey))
    }
}

private extension BatteryMigrationProofTests {
    func makeWallet(walletId: String) -> Wallet {
        Wallet(
            id: "wallet-id",
            identity: WalletIdentity(
                network: .mainnet,
                kind: .Regular(TonSwift.PublicKey(data: Data(repeating: 1, count: 32)), .v4R2)
            ),
            metaData: WalletMetaData(label: "Wallet", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings(),
            multichain: .multichain(
                MultichainWalletState(
                    walletId: walletId,
                    addresses: [MultichainWalletAddress(chain: .ton, address: "ton-address")]
                )
            )
        )
    }
}

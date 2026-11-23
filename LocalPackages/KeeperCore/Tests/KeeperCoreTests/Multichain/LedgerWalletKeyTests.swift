import ChainKit
import CryptoKit
@testable import KeeperCore
import XCTest

/// ChainKit's `LedgerWallet` turns the TON app's signature of the wallet key proof into the wallet, and Android asks
/// the TON app for the same proof, so one Ledger account is one wallet on both platforms.
final class LedgerWalletKeyTests: XCTestCase {
    /// Changing any of these changes the wallet of every multichain Ledger.
    func testTheProofInputsArePinned() {
        XCTAssertEqual(LedgerWalletKey.proofDomain, "Keeper wallet")
        XCTAssertEqual(LedgerWalletKey.proofPayload, "keeper.ledger.wallet.key.v1")
        XCTAssertEqual(LedgerWalletKey.proofTimestamp, 0)
    }

    /// The vector of Android's `LedgerWalletSeedTest`.
    func testTheProofHashMatchesAndroid() throws {
        let tonPublicKey = bytes("d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a")

        let hash = try XCTUnwrap(LedgerWallet.companion.proofHash(tonPublicKey: tonPublicKey.asKotlinByteArray).getOrNull())

        XCTAssertEqual(hash.asData.hex, "3416d58a3123d2300eed47b8250ee070419f95bf71e692e664aa67590afafda9")
    }

    func testTheProofGivesALedgerWallet() throws {
        let tonKey = Curve25519.Signing.PrivateKey()

        let wallet = try LedgerWalletKey.wallet(tonPublicKey: tonKey.publicKey.rawRepresentation, proofSignature: proof(by: tonKey))

        XCTAssertEqual(wallet.seed.count, 64)
        XCTAssertTrue(wallet.walletId.hasPrefix("aka"), "expected a ledger wallet_id, got \(wallet.walletId)")
        let keyPair = try XCTUnwrap(
            WalletKeyPair.companion.fromPrivateKey(privateKey: wallet.appPrivateKey.asKotlinByteArray, walletId: wallet.walletId).getOrNull()
        )
        XCTAssertEqual(keyPair.kind, .ledger)
    }

    func testTheKeptSeedRestoresTheWallet() throws {
        let tonKey = Curve25519.Signing.PrivateKey()
        let wallet = try LedgerWalletKey.wallet(tonPublicKey: tonKey.publicKey.rawRepresentation, proofSignature: proof(by: tonKey))

        let restored = try XCTUnwrap(LedgerWallet.companion.fromSeed(seed: wallet.seed.asKotlinByteArray).getOrNull())

        XCTAssertEqual(restored.walletIdV2(), wallet.walletId)
        XCTAssertEqual(restored.walletKeyPair().privateKey.asData, wallet.appPrivateKey)
    }

    func testAnotherAccountsProofIsRefused() throws {
        let tonKey = Curve25519.Signing.PrivateKey()
        let otherKey = Curve25519.Signing.PrivateKey()

        XCTAssertThrowsError(
            try LedgerWalletKey.wallet(tonPublicKey: otherKey.publicKey.rawRepresentation, proofSignature: proof(by: tonKey))
        )
    }

    private func proof(by tonKey: Curve25519.Signing.PrivateKey) throws -> Data {
        let hash = try XCTUnwrap(
            LedgerWallet.companion.proofHash(tonPublicKey: tonKey.publicKey.rawRepresentation.asKotlinByteArray).getOrNull()
        )
        return try tonKey.signature(for: hash.asData)
    }
}

private func bytes(_ hex: String) -> Data {
    Data(stride(from: 0, to: hex.count, by: 2).map { offset in
        let start = hex.index(hex.startIndex, offsetBy: offset)
        return UInt8(hex[start ..< hex.index(start, offsetBy: 2)], radix: 16) ?? 0
    })
}

private extension Data {
    var hex: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

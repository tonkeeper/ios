import ChainKit
import Foundation
@testable import KeeperCore
import XCTest

/// `makeBatterySendProof` is best-effort at both call sites — a throw only costs the message its
/// proof, it never fails the send. That makes a systematic breakage (a renamed wallet kind, a
/// chain-kit signature change) invisible in the app, so the contract is pinned here instead.
final class MultichainBatterySendProofTests: XCTestCase {
    /// Canonical BIP39 zero-entropy vector — deterministic, no secrets.
    private let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    private let boc = "te6ccgECBQEAARUAAkWIAWTtae+KgtbrX26Bep8JSq8lFLfGOoyGR/xwdjfvpvEaHg"

    /// The wallet root key is secp256k1 since the format 2 wallet id, so the proof is a 65-byte
    /// compact recoverable signature. Chain-kit lays it out as `R ‖ S ‖ recovery_id` — the
    /// recovery byte trails and is 0 or 1, never a `27 + recovery_id` header in front. Pinned
    /// here because nothing else on the client would notice the layout flipping.
    func testBatterySendProofIsCompactRecoverableSignature() throws {
        let signature = try makeProof(walletId: "wallet-id", boc: boc)

        XCTAssertEqual(signature.count, 130, "expected a hex-encoded 65-byte secp256k1 signature")
        XCTAssertTrue(signature.allSatisfy(\.isHexDigit))
        XCTAssertTrue(
            ["00", "01"].contains(String(signature.suffix(2))),
            "expected a trailing recovery id of 0 or 1, got \(signature.suffix(2))"
        )
    }

    /// The proof binds the message it travels with, so migration has to ask for one per BOC
    /// rather than reuse a single proof across the batch.
    func testBatterySendProofBindsTheBoc() throws {
        let signature = try makeProof(walletId: "wallet-id", boc: boc)
        let other = try makeProof(walletId: "wallet-id", boc: String(boc.dropLast()) + "A")

        XCTAssertNotEqual(signature, other)
    }

    func testBatterySendProofBindsTheWalletId() throws {
        let signature = try makeProof(walletId: "wallet-id", boc: boc)
        let other = try makeProof(walletId: "other-wallet-id", boc: boc)

        XCTAssertNotEqual(signature, other)
    }

    private func makeProof(walletId: String, boc: String) throws -> String {
        let wallet = try CryptoWallet.Companion.shared.fromMnemonic(mnemonic_: mnemonic)
        let keyPair = wallet.walletKeyPair(kind: ChainKitServiceImplementation.walletKind)
        defer { keyPair.privateKey.fillZeros() }
        return WalletAuth().signBatterySendProof(
            keyPair: keyPair,
            walletId: walletId,
            chain: "ton",
            boc: boc
        ).signature
    }
}

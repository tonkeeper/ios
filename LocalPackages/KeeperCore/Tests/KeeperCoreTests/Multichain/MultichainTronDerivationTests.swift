import ChainKit
import Foundation
@testable import KeeperCore
import TronSwift
import XCTest

/// TK-2139 Phase 0 de-risk. Multichain (BIP39) wallets derive their TRON key on
/// the raw seed via BIP44 `m/44'/195'`, which is a DIFFERENT address from the
/// legacy `TonTron` scheme (that re-seeds through `patchTonEntropy`). So the TRON
/// half of the multichain fee flow must sign with the ChainKit-derived key and
/// target the address held in `MultichainWalletState` — never `wallet.tron`.
final class MultichainTronDerivationTests: XCTestCase {
    /// Canonical BIP39 zero-entropy vector — deterministic, no secrets.
    private let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"

    /// The raw private key `ChainKitService.tronPrivateKey(mnemonic:)` returns must
    /// control exactly the TRON address ChainKit exposes via `getAddress(.tron)`.
    /// This also pins the key format (Risk #2): a non-raw / non-32-byte scalar would
    /// derive a different address and fail the equality.
    func testTronPrivateKeyControlsMultichainTronAddress() throws {
        let cryptoWallet = try CryptoWallet.Companion.shared.fromMnemonic(mnemonic_: mnemonic)
        let expectedAddress = cryptoWallet
            .getAddress(chain: MultichainChain.tron.asChainKitChain)
            .display

        let rawKey = cryptoWallet
            .getPrivateKey(chain: MultichainChain.tron.asChainKitChain)
            .data()
            .asData
        XCTAssertEqual(rawKey.count, 32, "expected a raw 32-byte secp256k1 scalar, got \(rawKey.count) bytes")

        let derivedAddress = try tronAddress(fromRawPrivateKey: rawKey)
        XCTAssertEqual(
            derivedAddress,
            expectedAddress,
            "tron key derived via ChainKit must control the multichain-state tron address"
        )
    }

    private func tronAddress(fromRawPrivateKey raw: Data) throws -> String {
        let privateKey = TronSwift.PrivateKey(data: raw, chainCode: Data())
        let publicKey = privateKey.publicKey(compressed: false, curve: Secp256k1DerivationCurve())
        return try TronSwift.Address(publicKey: publicKey).base58
    }
}

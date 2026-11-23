import ChainKit
import Foundation

/// The backend identity of a multichain Ledger wallet: ChainKit's `LedgerWallet` derives it from a TON address proof
/// the Ledger signs with fixed inputs. Ed25519 signatures are deterministic, so one Ledger account yields the same
/// wallet on every phone and platform.
@frozen public enum LedgerWalletKey {
    public static let proofDomain = LedgerWallet.companion.PROOF_DOMAIN
    public static let proofPayload = LedgerWallet.companion.PROOF_PAYLOAD
    public static let proofTimestamp = UInt64(LedgerWallet.companion.PROOF_TIMESTAMP)

    @frozen public enum Failure: Error {
        case notWalletKeyProof
    }

    /// The wallet of the account whose TON key signed the wallet key proof: the seed its app keys hang off, its auth
    /// key and its wallet id, of kind ledger.
    static func wallet(tonPublicKey: Data, proofSignature: Data) throws -> (seed: Data, appPrivateKey: Data, walletId: String) {
        guard let wallet = LedgerWallet.companion.fromProofSignature(
            tonPublicKey: tonPublicKey.asKotlinByteArray,
            proofSignature: proofSignature.asKotlinByteArray
        ).getOrNull() else {
            throw Failure.notWalletKeyProof
        }
        let seed = wallet.seed()
        defer { seed.fillZeros() }
        let keyPair = wallet.walletKeyPair()
        defer { keyPair.privateKey.fillZeros() }
        return (seed.asData, keyPair.privateKey.asData, keyPair.walletIdV2())
    }
}

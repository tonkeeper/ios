import ChainKit
import Foundation

/// A TON coin transfer's comment sent encrypted to the recipient's key: the transfer is priced and
/// reviewed carrying a stand-in of the comment's size, and the comment is encrypted into its place once
/// the wallet is unlocked.
struct MultichainEncryptedComment: Sendable, Hashable {
    let text: String
    /// The recipient's TON public key, hex.
    let recipientKey: String

    /// `text` encrypted to `key`; `nil` when there is no comment chain-kit encrypts or no key to encrypt it to.
    init?(text: String?, key: String?) {
        guard let text, Self.encrypts(text), let key, !key.isEmpty else {
            return nil
        }
        self.text = text
        self.recipientKey = key
    }

    /// Whether chain-kit encrypts `text`: it refuses a blank comment, and only once the wallet is unlocked.
    static func encrypts(_ text: String) -> Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The longest comment, in UTF-8 bytes, chain-kit encrypts.
    static var maxBytes: Int {
        Int(TonMessageEncryptor.companion.MAX_MEMO_BYTES)
    }

    /// Only a TON coin send carries one, as its body: a jetton's body is its transfer.
    static func isCarried(by asset: MultichainAsset) -> Bool {
        asset.asset.chain == .ton && asset.isNative
    }

    /// What the comment is priced and reviewed as before it is encrypted: chain-kit's filler of its size.
    func standIn(account: ChainKit.Account, client: CryptoKitClient) async throws -> String {
        let result = try await client.tonMessageEncryptor.emulationPayload(
            memoByteSize: Int32(text.utf8.count),
            account: account,
            recipientPublicKey: recipientPublicKey
        )
        guard let payload = result.getOrNull() else {
            throw ChainKitOperationError.malformed("the encrypted comment's stand-in: \(result.error?.logValue ?? "unknown")")
        }
        return payload as String
    }

    /// The comment encrypted from `account` with the unlocked keys, as the body that takes the stand-in's place.
    func encrypted(account: ChainKit.Account, wallet: MnemonicWallet, client: CryptoKitClient) async throws -> String {
        let result = try await client.tonMessageEncryptor.encrypt(
            memo: text,
            account: account,
            recipientPublicKey: recipientPublicKey,
            privateKey: wallet.getPrivateKey(chain: account.chain)
        )
        guard let body = result.getOrNull() else {
            throw ChainKitOperationError.signingFailed(payloadId: "main", reason: "the comment could not be encrypted: \(result.error?.logValue ?? "unknown")")
        }
        return body as String
    }

    private var recipientPublicKey: PubKey {
        PubKey(defaultHex: recipientKey, segWit: "")
    }
}

extension SignableOperation {
    /// The TON coin send with `body` in place of its comment: the encrypted comment, or the stand-in it
    /// is priced and reviewed as.
    func carrying(body: String) throws -> SignableOperation {
        guard operation.payloads.count == 1,
              let payload = operation.payloads.first,
              let main = payload.meta as? PayloadMetaTonMain,
              main.token == nil
        else {
            throw ChainKitOperationError.malformed("only a TON coin send carries a body in place of its comment")
        }
        let meta = main.doCopy(
            to: main.to,
            value: main.value,
            body: body,
            bounce: main.bounce,
            mode: main.mode,
            stateInit: main.stateInit,
            expireAt: main.expireAt,
            comment: nil,
            token: nil
        )
        let carried = ChainKit.Payload(
            id: payload.id,
            type: payload.type,
            chain: payload.chain,
            version: payload.version,
            fee: payload.fee,
            meta: meta
        )
        return SignableOperation(
            // A `main` meta chain-kit typed itself is written with no JSON to read, so `build` cannot fail on it.
            operation: ChainKit.Operation.Companion.shared.build(id: operation.id, payloads: [carried]),
            account: account,
            intent: intent,
            fidelity: fidelity
        )
    }
}

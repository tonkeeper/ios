import TonSwift

public extension MultichainActivityEncryptedComment {
    /// The comment as the TON decryption reads it; `nil` when its sender is no TON address.
    var payload: EncryptedCommentPayload? {
        guard let sender = try? Address.parse(senderAddress) else {
            return nil
        }
        return EncryptedCommentPayload(
            encryptedComment: EncryptedComment(type: .simple, cipherText: cipherText),
            senderAddress: sender
        )
    }
}

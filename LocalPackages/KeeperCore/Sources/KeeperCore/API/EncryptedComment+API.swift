import Foundation
import TonAPI
import TonSwift

extension EncryptedComment {
    init?(encryptedComment: TonAPI.Components.Schemas.EncryptedComment?) {
        guard let encryptedComment,
              let type = EncryptedCommentType(rawValue: encryptedComment.encryptionType) else { return nil }
        self.type = type
        self.cipherText = encryptedComment.cipherText
    }
}

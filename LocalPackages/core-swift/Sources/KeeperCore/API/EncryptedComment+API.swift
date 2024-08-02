import Foundation
import TonSwift
import TonAPI

extension EncryptedComment {
  init?(encryptedComment: Components.Schemas.EncryptedComment?) {
    guard let encryptedComment,
    let type = EncryptedCommentType(rawValue: encryptedComment.encryption_type)else { return nil }
    self.type = type
    self.cipherText = encryptedComment.cipher_text
  }
}


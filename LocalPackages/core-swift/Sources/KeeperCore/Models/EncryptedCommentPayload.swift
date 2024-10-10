import Foundation
import TonSwift

public struct EncryptedCommentPayload {
  public let encryptedComment: EncryptedComment
  public let senderAddress: Address
  
  public init(encryptedComment: EncryptedComment, 
              senderAddress: Address) {
    self.encryptedComment = encryptedComment
    self.senderAddress = senderAddress
  }
}

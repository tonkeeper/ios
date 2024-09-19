import Foundation
import TonSwift

public struct EncryptedCommentPayload {
  public let encryptedComment: EncryptedComment
  public let senderAddress: Address
}

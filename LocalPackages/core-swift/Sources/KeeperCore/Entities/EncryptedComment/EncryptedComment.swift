import Foundation

public struct EncryptedComment: Codable {
  public enum EncryptedCommentType: String, Codable {
    case simple
  }
  
  public let type: EncryptedCommentType
  public let cipherText: String
}

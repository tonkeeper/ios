import Foundation

public struct EncryptedMnemonics: Codable {
  public let kind: String
  public let N: Int
  public let r: Int
  public let p: Int
  public let salt: String
  public let ct: String
}

import Foundation
import TonSwift

public enum LedgerWalletRevision: String, Codable {
  case v4R2
}

public struct LedgerAccount: Codable {
  public let publicKey: PublicKey
  public let revision: LedgerWalletRevision
  public let path: AccountPath
  
  public init(publicKey: PublicKey,
              revision: LedgerWalletRevision,
              path: AccountPath) {
    self.publicKey = publicKey
    self.revision = revision
    self.path = path
  }
  
  public var id: String {
    path.data.hexString() + revision.rawValue
  }
}

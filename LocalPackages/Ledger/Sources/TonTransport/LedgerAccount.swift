import Foundation
import TonSwift

public struct LedgerAccount: Codable {
  public let address: Address
  public let publicKey: PublicKey
  public let path: AccountPath
  
  public init(address: Address, publicKey: PublicKey, path: AccountPath) {
    self.address = address
    self.publicKey = publicKey
    self.path = path
  }
}

import Foundation
import TonSwift

public struct WalletKey: Codable, Hashable {
  public let name: String
  public let publicKey: TonSwift.PublicKey
  
  public static func == (lhs: WalletKey, rhs: WalletKey) -> Bool {
    lhs.publicKey.data == rhs.publicKey.data
  }
  
  public func hash(into hasher: inout Hasher) {
    hasher.combine(publicKey.data)
  }
  
  public var id: String {
    publicKey.hexString
  }
  
  public var publicKeyHexString: String {
    publicKey.hexString
  }
  
  public var publicKeyShortHexString: String {
    "\(publicKey.hexString.prefix(8))...\(publicKey.hexString.suffix(8))"
  }
}


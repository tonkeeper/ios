import Foundation
import TonSwift

public struct WalletID: Hashable, Codable {
  public let hash: Data
  public var string: String {
    hash.hexString()
  }
}

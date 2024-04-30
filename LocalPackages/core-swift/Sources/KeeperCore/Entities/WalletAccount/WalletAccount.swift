import Foundation
import TonSwift
import TonAPI

public struct WalletAccount: Equatable, Codable {
  public let address: Address
  public let name: String?
  public let isScam: Bool
  public let isWallet: Bool
}

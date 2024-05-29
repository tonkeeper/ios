import Foundation
import BigInt

public struct WalletBalance: Codable {
  let date: Date
  let balance: Balance
}

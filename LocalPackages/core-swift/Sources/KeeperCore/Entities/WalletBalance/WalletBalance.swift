import Foundation
import BigInt

public struct WalletBalance: Codable, Equatable {
  let date: Date
  let balance: Balance
}

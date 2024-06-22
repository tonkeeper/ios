import Foundation
import BigInt

public struct TotalBalance: Codable, Equatable {
  public let amount: BigUInt
  public let fractionalDigits: Int
  public let date: Date
}

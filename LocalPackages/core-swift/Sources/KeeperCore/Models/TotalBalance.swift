import Foundation
import BigInt

public struct TotalBalance: Codable, Equatable {
  let amount: BigUInt
  let fractionalDigits: Int
  let date: Date
}

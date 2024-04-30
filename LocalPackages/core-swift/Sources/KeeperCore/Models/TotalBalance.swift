import Foundation
import BigInt

public struct TotalBalance: Codable {
  let amount: BigUInt
  let fractionalDigits: Int
  let date: Date
}

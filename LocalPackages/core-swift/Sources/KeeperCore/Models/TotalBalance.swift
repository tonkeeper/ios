import Foundation
import BigInt

public struct TotalBalance: Codable, Equatable {
  public let amount: Decimal
  public let balance: ConvertedBalance
  public let currency: Currency
  public let date: Date
}

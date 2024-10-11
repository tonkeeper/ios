import Foundation
import BigInt

public struct TotalBalance: Codable, Equatable {
  public let amount: Decimal
  public let balance: ProcessedBalance
  public let batteryBalance: BatteryBalance?
  public let currency: Currency
  public let date: Date
}

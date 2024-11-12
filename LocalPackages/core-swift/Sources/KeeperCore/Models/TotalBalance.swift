import Foundation
import BigInt

public struct TotalBalance {
  public let amount: Decimal
  public let balance: ManagedBalance
  public let batteryBalance: BatteryBalance?
  public let currency: Currency
  public let date: Date
}

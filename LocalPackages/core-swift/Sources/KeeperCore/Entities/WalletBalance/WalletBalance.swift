import Foundation
import BigInt

public struct WalletBalance: Codable, Equatable {
  public let date: Date
  public let balance: Balance
  public let stacking: [AccountStackingInfo]
  public let batteryBalance: BatteryBalance?
}

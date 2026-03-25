import BigInt
import Foundation

public struct WalletBalance: Codable, Equatable {
    public let date: Date
    public let balance: Balance
    public let stacking: [AccountStackingInfo]
    public let batteryBalance: BatteryBalance?
    public let tronBalance: TronBalance?
}

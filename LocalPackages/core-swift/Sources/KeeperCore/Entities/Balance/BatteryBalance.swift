import Foundation
import TonSwift
import BigInt

public struct BatteryBalance: Codable, Equatable {
  public let balance: String
  public let reserved: String
}

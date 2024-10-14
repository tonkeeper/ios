import Foundation
import TonSwift
import BigInt

public struct BatteryBalance: Codable, Equatable {
  
  public var balanceDecimalNumber: NSDecimalNumber? {
    NSDecimalNumber.number(stringValue: balance)
  }
  
  public var reservedDecimalNumber: NSDecimalNumber? {
    NSDecimalNumber.number(stringValue: reserved)
  }
  
  public let balance: String
  public let reserved: String
}

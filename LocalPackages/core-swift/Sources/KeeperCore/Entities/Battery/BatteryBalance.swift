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
  
  public var isZero: Bool {
    balanceDecimalNumber == NSDecimalNumber.zero && reservedDecimalNumber == NSDecimalNumber.zero
  }
  
  public var isBalanceZero: Bool {
    balanceDecimalNumber == NSDecimalNumber.zero
  }
}

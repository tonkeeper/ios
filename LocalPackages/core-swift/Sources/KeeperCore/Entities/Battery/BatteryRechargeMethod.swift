import Foundation
import TonSwift

public struct BatteryRechargeMethod {
  
  public var rateDecimalNumber: NSDecimalNumber? {
    NSDecimalNumber.number(stringValue: rate)
  }
  
  public var minBootstrapValueDecimalNumber: NSDecimalNumber? {
    NSDecimalNumber.number(stringValue: minBootstrapValue)
  }
  
  public enum Token {
    case ton
    case jetton(Jetton)
  }
  
  public struct Jetton {
    public let jettonMasterAddress: Address
  }
  
  public let token: Token
  public let imageURL: URL?
  public let minBootstrapValue: String?
  public let rate: String?
  public let symbol: String
  public let decimals: Int
  public let supportGasless: Bool
  public let supportRecharge: Bool
}

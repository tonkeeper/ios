import Foundation
import TonSwift

public struct BatteryRechargeMethod {
  
  public var rateDecimalNumber: NSDecimalNumber? {
    NSDecimalNumber.number(stringValue: rate)
  }
  
  public var minBootstrapValueDecimalNumber: NSDecimalNumber? {
    NSDecimalNumber.number(stringValue: minBootstrapValue)
  }
  
  public enum Token: Equatable {
    case ton
    case jetton(Jetton)
    
    public static func ==(lhs: Token, rhs: Token) -> Bool {
      switch (lhs, rhs) {
      case (.ton, .ton):
        return true
      case (.jetton(let lJetton), .jetton(let rJetton)):
        return lJetton.jettonMasterAddress == rJetton.jettonMasterAddress
      default:
        return false
      }
    }
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
  
  public var jettonMasterAddress: Address? {
    switch token {
    case .ton:
      nil
    case .jetton(let jetton):
      jetton.jettonMasterAddress
    }
  }
}

import Foundation

public enum Token: Equatable, Hashable {
  case ton
  case jetton(JettonItem)
  
 public var fractionDigits: Int {
    let digits: Int
    switch self {
    case .ton:
      digits = TonInfo.fractionDigits
    case .jetton(let jettonItem):
      digits = jettonItem.jettonInfo.fractionDigits
    }
    
    return digits
  }
  
  public var symbol: String {
    switch self {
    case .ton:
      return TonInfo.symbol
    case .jetton(let jettonItem):
      return jettonItem.jettonInfo.symbol ?? ""
    }
  }
  
  public var identifier: String {
    switch self {
    case .ton:
      return TonInfo.symbol
    case .jetton(let jettonItem):
      return jettonItem.jettonInfo.address.toRaw()
    }
  }
}

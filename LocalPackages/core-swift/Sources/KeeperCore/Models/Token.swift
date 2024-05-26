import Foundation

public enum Token: Equatable {
  case ton
  case jetton(JettonItem)
}

public extension Token {

  var tokenFractionalDigits: Int {
    let fractionDigits: Int
    switch self {
    case .ton:
      fractionDigits = TonInfo.fractionDigits
    case .jetton(let jettonItem):
      fractionDigits = jettonItem.jettonInfo.fractionDigits
    }
    return fractionDigits
  }

  var symbol: String? {
    switch self {
    case .ton: return TonInfo.symbol
    case .jetton(let jettonItem): return jettonItem.jettonInfo.symbol
    }
  }
}

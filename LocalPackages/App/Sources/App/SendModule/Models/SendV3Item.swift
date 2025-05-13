import Foundation
import KeeperCore
import BigInt
import TronSwift

enum SendV3Item {
  case ton(TonSendData.Item)
  case tron(TronSendData.Item)
  
  func setAmount(amount: BigUInt) -> SendV3Item {
    switch self {
    case .ton(let item):
      switch item {
      case .token(let token, _):
        return .ton(.token(token, amount: amount))
      case .nft:
        return self
      }
    case .tron(let item):
      switch item {
      case .usdt:
        return .tron(.usdt(amount: amount))
      }
    }
  }
  
  var fractionalDigits: Int {
    switch self {
    case .ton(let item):
      switch item {
      case .token(let token, _):
        return token.fractionDigits
      default:
        return 0
      }
    case .tron(let item):
      switch item {
      case .usdt:
        return TronSwift.USDT.fractionDigits
      }
    }
  }
  
  var amount: BigUInt {
    switch self {
    case .ton(let item):
      switch item {
      case .token(_, let amount):
        return amount
      default:
        return 0
      }
    case .tron(let item):
      switch item {
      case .usdt(let amount):
        return amount
      }
    }
  }
  
  var isSupportComment: Bool {
    switch self {
    case .ton:
      return true
    case .tron:
      return false
    }
  }
}

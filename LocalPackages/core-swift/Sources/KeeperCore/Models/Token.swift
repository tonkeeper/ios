import Foundation
import TronSwift

public enum Token: Equatable, Hashable {
  case ton(TonToken)
  case usdtTron
  
  public var fractionDigits: Int {
    switch self {
    case .ton(let tonToken): tonToken.fractionDigits
    case .usdtTron: TronSwift.USDT.fractionDigits
    }
  }
  
  public var symbol: String {
    switch self {
    case .ton(let tonToken): tonToken.symbol
    case .usdtTron: TronSwift.USDT.symbol
    }
  }

  public var chartIdentifier: String {
    switch self {
    case .ton(let tonToken): tonToken.identifier
    case .usdtTron: JettonMasterAddress.tonUSDT.toRaw()
    }
  }
}

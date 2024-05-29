import Foundation
import TonSwift

public enum Token: Equatable {
  case ton
  case jetton(JettonItem)
}

public extension Token {
    var tokenFractionDigits: Int {
        switch self {
        case .ton:
            return TonInfo.fractionDigits
        case .jetton(let jettonItem):
            return jettonItem.jettonInfo.fractionDigits
        }
    }
    
    var tokenSym: String {
        switch self {
        case .ton:
            return TonInfo.symbol
        case .jetton(let jettonItem):
            return jettonItem.jettonInfo.symbol ?? ""
        }
    }
    
    var tokenName: String {
        switch self {
        case .ton:
            return TonInfo.name
        case .jetton(let jettonItem):
            return jettonItem.jettonInfo.name
        }
    }
    
    var jettonInfo: JettonInfo? {
        switch self {
        case .ton:
            return nil
        case .jetton(let jettonItem):
            return jettonItem.jettonInfo
        }
    }
    
    var address: Address? {
        switch self {
        case .ton:
            return try? .parse(raw: STONFI_CONSTANTS.TONProxyAddress)
        case .jetton(let jettonItem):
            return jettonItem.walletAddress
        }
    }
}

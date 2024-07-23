import Foundation
import TonSwift
import BigInt

public enum ConvertedBalanceState: Equatable {
  case current(ConvertedBalance)
  case previous(ConvertedBalance)
  
  public var balance: ConvertedBalance {
    switch self {
    case .current(let convertedBalance):
      return convertedBalance
    case .previous(let convertedBalance):
      return convertedBalance
    }
  }
}

public struct ConvertedBalance: Codable, Equatable {
  public let date: Date
  public let currency: Currency
  public let tonBalance: ConvertedTonBalance
  public let jettonsBalance: [ConvertedJettonBalance]
  public let stackingBalance: [ConvertedStakingBalance]
}

public struct ConvertedTonBalance: Codable, Equatable {
  public let tonBalance: TonBalance
  public let converted: Decimal
  public let price: Decimal
  public let diff: String?
}

public struct ConvertedJettonBalance: Codable, Equatable {
  public let jettonBalance: JettonBalance
  public let converted: Decimal
  public let price: Decimal
  public let diff: String?
}

public struct ConvertedStakingBalance: Codable, Equatable {
  public let stackingInfo: AccountStackingInfo
  public let amountConverted: Decimal
  public let pendingDepositConverted: Decimal
  public let pendingWithdrawConverted: Decimal
  public let readyWithdrawConverted: Decimal
  public let price: Decimal
}

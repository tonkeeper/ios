import Foundation
import BigInt

public struct ProcessedBalance: Equatable, Codable {
  public let items: [ProcessedBalanceItem]
  public let tonItem: ProcessedBalanceTonItem
  public let jettonItems: [ProcessedBalanceJettonItem]
  public let stakingItems: [ProcessedBalanceStakingItem]
  public let batteryBalance: BatteryBalance?
  
  public let currency: Currency
  public let date: Date
}

public enum ProcessedBalanceItem: Equatable, Codable {
  case ton(ProcessedBalanceTonItem)
  case jetton(ProcessedBalanceJettonItem)
  case staking(ProcessedBalanceStakingItem)
  
  var converted: Decimal {
    switch self {
    case .ton(let item):
      return item.converted
    case .jetton(let item):
      return item.converted
    case .staking(let item):
      return item.amountConverted
    }
  }
  
  public var identifier: String {
    switch self {
    case .ton:
      return TonInfo.symbol
    case .jetton(let jetton):
      return jetton.jetton.jettonInfo.address.toRaw()
    case .staking(let staking):
      return staking.info.pool.toRaw()
    }
  }
}

public struct ProcessedBalanceTonItem: Equatable, Codable {
  public let id: String
  public let title: String
  public let amount: UInt64
  public let fractionalDigits: Int
  public let currency: Currency
  public let converted: Decimal
  public let price: Decimal
  public let diff: String?
}

public struct ProcessedBalanceJettonItem: Equatable, Codable {
  public let id: String
  public let jetton: JettonItem
  public let amount: BigUInt
  public let fractionalDigits: Int
  public let tag: String?
  public let currency: Currency
  public let converted: Decimal
  public let price: Decimal
  public let diff: String?
}

public struct ProcessedBalanceStakingItem: Equatable, Codable {
  public let id: String
  public let info: AccountStackingInfo
  public let poolInfo: StackingPoolInfo?
  public let jetton: ProcessedBalanceJettonItem?
  public let currency: Currency
  public let amountConverted: Decimal
  public let pendingDepositConverted: Decimal
  public let pendingWithdrawConverted: Decimal
  public let readyWithdrawConverted: Decimal
  public let price: Decimal
}


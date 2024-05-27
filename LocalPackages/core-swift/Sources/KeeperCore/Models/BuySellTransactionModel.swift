import Foundation
import BigInt

public struct BuySellTransactionModel {
  public enum MinimumLimits {
    case amount(buy: BigUInt, sell: BigUInt)
    case none
  }
  
  public let operation: BuySellModel.Operation
  public var buySellItem: BuySellItem
  public let providerRate: Decimal?
  public let minimumLimits: MinimumLimits
  
  public init(operation: BuySellModel.Operation,
              buySellItem: BuySellItem,
              providerRate: Decimal?,
              minimumLimits: MinimumLimits) {
    self.operation = operation
    self.buySellItem = buySellItem
    self.providerRate = providerRate
    self.minimumLimits = minimumLimits
  }
}

extension BuySellTransactionModel {
  public var itemBuy: BuySellItem.Item {
    switch operation {
    case .buy:
      return buySellItem.tokenItem
    case .sell:
      return buySellItem.fiatItem
    }
  }
  
  public var itemSell: BuySellItem.Item {
    switch operation {
    case .buy:
      return buySellItem.fiatItem
    case .sell:
      return buySellItem.tokenItem
    }
  }
}

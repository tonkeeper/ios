import Foundation
import BigInt

public struct BuySellTransactionModel {
  public enum MinimumLimits {
    case amount(buy: BigUInt, sell: BigUInt)
    case none
  }
  
  public enum Operation {
    case buyTon(fiatCurrency: Currency)
    case sellTon(fiatCurrency: Currency)
    
    public var fiatCurrency: Currency {
      switch self {
      case .buyTon(let fiatCurrency), .sellTon(let fiatCurrency):
        return fiatCurrency
      }
    }
  }
  
  public let operation: Operation
  public let token: BuySellModel.Token
  public var inputAmount: BigUInt
  public let providerRate: Decimal
  public let minimumLimits: MinimumLimits
  
  public init(operation: Operation,
              token: BuySellModel.Token,
              inputAmount: BigUInt,
              providerRate: Decimal,
              minimumLimits: MinimumLimits) {
    self.operation = operation
    self.token = token
    self.inputAmount = inputAmount
    self.providerRate = providerRate
    self.minimumLimits = minimumLimits
  }
}

extension BuySellTransactionModel {
  public var currencyPay: Currency {
    switch operation {
    case .buyTon(let fiatCurrency):
      return fiatCurrency
    case .sellTon:
      return .TON
    }
  }
  
  public var currencyGet: Currency {
    switch operation {
    case .buyTon:
      return .TON
    case .sellTon(let fiatCurrency):
      return fiatCurrency
    }
  }
}

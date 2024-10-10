import Foundation
import BigInt

public enum AccountEventActionAmountMapperActionType {
  case income
  case outcome
  case none
  
  var sign: String {
    switch self {
    case .income: return "\(String.Symbol.plus)\(String.Symbol.shortSpace)"
    case .outcome: return "\(String.Symbol.minus)\(String.Symbol.shortSpace)"
    case .none: return ""
    }
  }
}

public protocol AccountEventAmountMapper {
  func mapAmount(amount: BigUInt,
                 fractionDigits: Int,
                 maximumFractionDigits: Int,
                 type: AccountEventActionAmountMapperActionType,
                 currency: Currency?) -> String
  
  func mapAmount(amount: BigUInt,
                 fractionDigits: Int,
                 maximumFractionDigits: Int,
                 type: AccountEventActionAmountMapperActionType,
                 symbol: String?) -> String
}

public struct PlainAccountEventAmountMapper: AccountEventAmountMapper {
  private let amountFormatter: AmountFormatter
  
  public init(amountFormatter: AmountFormatter) {
    self.amountFormatter = amountFormatter
  }
  
  public func mapAmount(amount: BigUInt,
                        fractionDigits: Int,
                        maximumFractionDigits: Int,
                        type: AccountEventActionAmountMapperActionType,
                        currency: Currency?) -> String {
    amountFormatter.formatAmount(
      amount,
      fractionDigits: fractionDigits,
      maximumFractionDigits: maximumFractionDigits,
      currency: currency)
  }
  
  public func mapAmount(amount: BigUInt,
                        fractionDigits: Int,
                        maximumFractionDigits: Int,
                        type: AccountEventActionAmountMapperActionType,
                        symbol: String?) -> String {
    amountFormatter.formatAmount(
      amount,
      fractionDigits: fractionDigits,
      maximumFractionDigits: maximumFractionDigits,
      symbol: symbol)
  }
}

public struct SignedAccountEventAmountMapper: AccountEventAmountMapper {
  let plainAccountEventAmountMapper: AccountEventAmountMapper
  
  public init(plainAccountEventAmountMapper: AccountEventAmountMapper) {
    self.plainAccountEventAmountMapper = plainAccountEventAmountMapper
  }
  
  public func mapAmount(amount: BigUInt,
                        fractionDigits: Int,
                        maximumFractionDigits: Int,
                        type: AccountEventActionAmountMapperActionType,
                        currency: Currency?) -> String {
    return type.sign + plainAccountEventAmountMapper
      .mapAmount(
        amount: amount,
        fractionDigits: fractionDigits,
        maximumFractionDigits: maximumFractionDigits,
        type: type,
        currency: currency
      )
  }
  
  public func mapAmount(amount: BigUInt,
                        fractionDigits: Int,
                        maximumFractionDigits: Int,
                        type: AccountEventActionAmountMapperActionType,
                        symbol: String?) -> String {
    return type.sign + plainAccountEventAmountMapper
      .mapAmount(
        amount: amount,
        fractionDigits: fractionDigits,
        maximumFractionDigits: maximumFractionDigits,
        type: type,
        symbol: symbol
      )
  }
}

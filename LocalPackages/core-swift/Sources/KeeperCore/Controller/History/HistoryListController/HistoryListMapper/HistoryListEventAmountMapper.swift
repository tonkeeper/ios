import Foundation
import BigInt

enum HistoryEventActionAmountMapperActionType {
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

protocol HistoryListEventAmountMapper {
  func mapAmount(amount: BigUInt,
                 fractionDigits: Int,
                 maximumFractionDigits: Int,
                 type: HistoryEventActionAmountMapperActionType,
                 currency: Currency?) -> String
  
  func mapAmount(amount: BigUInt,
                 fractionDigits: Int,
                 maximumFractionDigits: Int,
                 type: HistoryEventActionAmountMapperActionType,
                 symbol: String?) -> String
}

struct AmountHistoryListEventAmountMapper: HistoryListEventAmountMapper {
  private let amountFormatter: AmountFormatter
  
  init(amountFormatter: AmountFormatter) {
    self.amountFormatter = amountFormatter
  }
  
  func mapAmount(amount: BigUInt,
                 fractionDigits: Int,
                 maximumFractionDigits: Int,
                 type: HistoryEventActionAmountMapperActionType,
                 currency: Currency?) -> String {
    amountFormatter.formatAmount(
      amount,
      fractionDigits: fractionDigits,
      maximumFractionDigits: maximumFractionDigits,
      currency: currency)
  }
  
  func mapAmount(amount: BigUInt,
                 fractionDigits: Int,
                 maximumFractionDigits: Int,
                 type: HistoryEventActionAmountMapperActionType,
                 symbol: String?) -> String {
    amountFormatter.formatAmount(
      amount,
      fractionDigits: fractionDigits,
      maximumFractionDigits: maximumFractionDigits,
      symbol: symbol)
  }
}

struct SignedAmountHistoryListEventAmountMapper: HistoryListEventAmountMapper {
  let amountAccountHistoryListEventAmountMapper: HistoryListEventAmountMapper
  
  init(amountAccountHistoryListEventAmountMapper: HistoryListEventAmountMapper) {
    self.amountAccountHistoryListEventAmountMapper = amountAccountHistoryListEventAmountMapper
  }
  
  func mapAmount(amount: BigUInt,
                 fractionDigits: Int,
                 maximumFractionDigits: Int,
                 type: HistoryEventActionAmountMapperActionType,
                 currency: Currency?) -> String {
    return type.sign + amountAccountHistoryListEventAmountMapper
      .mapAmount(
        amount: amount,
        fractionDigits: fractionDigits,
        maximumFractionDigits: maximumFractionDigits,
        type: type,
        currency: currency
      )
  }
  
  func mapAmount(amount: BigUInt,
                 fractionDigits: Int,
                 maximumFractionDigits: Int,
                 type: HistoryEventActionAmountMapperActionType,
                 symbol: String?) -> String {
    return type.sign + amountAccountHistoryListEventAmountMapper
      .mapAmount(
        amount: amount,
        fractionDigits: fractionDigits,
        maximumFractionDigits: maximumFractionDigits,
        type: type,
        symbol: symbol
      )
  }
}

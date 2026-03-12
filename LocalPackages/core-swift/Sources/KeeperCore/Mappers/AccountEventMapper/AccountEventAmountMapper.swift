import BigInt
import Foundation

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
    func mapAmount(
        amount: BigUInt,
        fractionDigits: Int,
        type: AccountEventActionAmountMapperActionType,
        currency: Currency?
    ) -> String

    func mapAmount(
        amount: BigUInt,
        fractionDigits: Int,
        type: AccountEventActionAmountMapperActionType,
        symbol: String?
    ) -> String
}

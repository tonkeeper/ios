import BigInt
import Core
import Foundation
import KeeperCore

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

public struct PlainAccountEventAmountMapper: AccountEventAmountMapper {
    private let amountFormatter: AmountFormatter

    public init(amountFormatter: AmountFormatter) {
        self.amountFormatter = amountFormatter
    }

    public func mapAmount(
        amount: BigUInt,
        fractionDigits: Int,
        type: AccountEventActionAmountMapperActionType,
        currency: Currency?
    ) -> String {
        amountFormatter.format(
            amount: amount,
            fractionDigits: fractionDigits,
            accessory: currency.flatMap { .currency($0) } ?? .none
        )
    }

    public func mapAmount(
        amount: BigUInt,
        fractionDigits: Int,
        type: AccountEventActionAmountMapperActionType,
        symbol: String?
    ) -> String {
        amountFormatter.format(
            amount: amount,
            fractionDigits: fractionDigits,
            accessory: symbol.flatMap { .symbol($0) } ?? .none
        )
    }
}

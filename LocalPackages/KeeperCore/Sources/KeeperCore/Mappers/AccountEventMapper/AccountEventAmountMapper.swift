import BigInt
import Foundation

public enum AccountEventActionAmountMapperActionType {
    case income
    case outcome
    case none
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

struct SignedAccountEventAmountMapper: AccountEventAmountMapper {
    private let amountFormatter: AmountFormatter

    init(amountFormatter: AmountFormatter) {
        self.amountFormatter = amountFormatter
    }

    func mapAmount(
        amount: BigUInt,
        fractionDigits: Int,
        type: AccountEventActionAmountMapperActionType,
        currency: Currency?
    ) -> String {
        amountFormatter.format(
            amount: amount,
            fractionDigits: fractionDigits,
            accessory: currency.flatMap { .token($0) } ?? .none,
            isNegative: type == .outcome
        )
    }

    func mapAmount(
        amount: BigUInt,
        fractionDigits: Int,
        type: AccountEventActionAmountMapperActionType,
        symbol: String?
    ) -> String {
        amountFormatter.format(
            amount: amount,
            fractionDigits: fractionDigits,
            accessory: symbol.flatMap { .tokenSymbol($0) } ?? .none,
            isNegative: type == .outcome
        )
    }
}

public struct PlainAccountEventAmountMapper: AccountEventAmountMapper {
    private let amountFormatter: AmountFormatter

    public init(amountFormatter: AmountFormatter) {
        self.amountFormatter = amountFormatter
    }

    public func mapAmount(
        amount: BigUInt,
        fractionDigits: Int,
        type _: AccountEventActionAmountMapperActionType,
        currency: Currency?
    ) -> String {
        amountFormatter.format(
            amount: amount,
            fractionDigits: fractionDigits,
            accessory: currency.flatMap { .token($0) } ?? .none
        )
    }

    public func mapAmount(
        amount: BigUInt,
        fractionDigits: Int,
        type _: AccountEventActionAmountMapperActionType,
        symbol: String?
    ) -> String {
        amountFormatter.format(
            amount: amount,
            fractionDigits: fractionDigits,
            accessory: symbol.flatMap { .tokenSymbol($0) } ?? .none
        )
    }
}

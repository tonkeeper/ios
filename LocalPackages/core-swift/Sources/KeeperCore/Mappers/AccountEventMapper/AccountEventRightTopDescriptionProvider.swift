import BigInt
import Foundation

public protocol AccountEventRightTopDescriptionProvider {
    mutating func rightTopDescription(
        accountEvent: AccountEvent,
        action: AccountEventAction
    ) -> String?
}

public struct SignRawConfirmationAccountEventRightTopDescriptionProvider: AccountEventRightTopDescriptionProvider {
    private let rates: Rates.Rate?
    private let currency: Currency
    private let formatter: AmountFormatter

    public init(
        rates: Rates.Rate?,
        currency: Currency,
        formatter: AmountFormatter
    ) {
        self.rates = rates
        self.currency = currency
        self.formatter = formatter
    }

    public mutating func rightTopDescription(
        accountEvent _: AccountEvent,
        action: AccountEventAction
    ) -> String? {
        guard let rates = rates else { return nil }

        let rateConverter = RateConverter()
        let convertResult: (BigUInt, Int)

        switch action.type {
        case let .tonTransfer(tonTransfer):
            convertResult = rateConverter.convert(
                amount: tonTransfer.amount,
                amountFractionLength: TonInfo.fractionDigits,
                rate: rates
            )
        case let .nftPurchase(nftPurchase):
            convertResult = rateConverter.convert(
                amount: nftPurchase.price,
                amountFractionLength: TonInfo.fractionDigits,
                rate: rates
            )
        default:
            return nil
        }
        return "\(currency.symbol)" + formatter.format(
            amount: convertResult.0,
            fractionDigits: convertResult.1
        )
    }
}

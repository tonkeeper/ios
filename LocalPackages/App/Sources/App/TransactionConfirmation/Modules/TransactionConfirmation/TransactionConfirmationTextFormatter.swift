import BigInt
import KeeperCore
import TKLocalize

struct TransactionConfirmationTextFormatter {
    private let amountFormatter: AmountFormatter

    init(amountFormatter: AmountFormatter) {
        self.amountFormatter = amountFormatter
    }

    func formatFeeList(
        fee: TransactionConfirmationFeeCalculator.FeeDetails,
        rate: Rates.Rate?,
        tonRate: Rates.Rate?,
        currency: Currency
    ) -> (topValue: String, bottomValue: String?) {
        switch fee.kind {
        case let .battery(charges, excess, estimatedTONAmount):
            guard let charges else {
                return ("", nil)
            }

            let feeValue = "\(charges) \(TKLocales.Battery.Refill.chargesCount(count: charges))"
            if !fee.isRefund, let excess {
                return (
                    feeValue,
                    "\(TKLocales.Common.Numbers.approximate) \(excess) \(TKLocales.Battery.Refill.refunded(count: excess))"
                )
            }

            guard let estimatedTONAmount, let tonRate else {
                return (feeValue, nil)
            }
            return (
                feeValue,
                formatFiat(
                    amount: estimatedTONAmount,
                    fractionDigits: TonInfo.fractionDigits,
                    rate: tonRate,
                    currency: currency
                )
            )

        case let .token(amount, fractionDigits, symbol, _):
            let topValue = amountFormatter.format(
                amount: amount,
                fractionDigits: fractionDigits,
                accessory: .symbol(symbol)
            )
            let bottomValue: String? = {
                guard let rate else { return nil }
                return formatFiat(
                    amount: amount,
                    fractionDigits: fractionDigits,
                    rate: rate,
                    currency: currency
                )
            }()
            return (topValue, bottomValue)
        }
    }

    func formatFeeOptionDescription(
        feeKind: TransactionConfirmationFeeCalculator.FeeKind,
        currency: Currency,
        tonRate: Rates.Rate?,
        trxRate: Rates.Rate?
    ) -> String? {
        switch feeKind {
        case let .battery(charges, _, estimatedTONAmount):
            guard let charges else { return nil }
            let chargesText = "\(charges) \(TKLocales.Battery.Refill.chargesCount(count: charges))"

            guard
                let tonRate,
                let estimatedTONAmount,
                let fiat = formatFiat(
                    amount: estimatedTONAmount,
                    fractionDigits: TonInfo.fractionDigits,
                    rate: tonRate,
                    currency: currency
                )
            else {
                return "\(TKLocales.Common.Numbers.approximate) \(chargesText)"
            }
            return "\(TKLocales.Common.Numbers.approximate) \(fiat) (\(chargesText))"

        case let .token(amount, fractionDigits, symbol, tokenKind):
            let tokenText = formatTokenAmount(
                amount: amount,
                fractionDigits: fractionDigits,
                symbol: symbol
            )
            let rate: Rates.Rate? = {
                switch tokenKind {
                case .ton:
                    tonRate
                case .trx:
                    trxRate
                case .other:
                    nil
                }
            }()
            guard let rate,
                  let fiat = formatFiat(
                      amount: amount,
                      fractionDigits: fractionDigits,
                      rate: rate,
                      currency: currency
                  )
            else {
                return "\(TKLocales.Common.Numbers.approximate) \(tokenText)"
            }
            return "\(TKLocales.Common.Numbers.approximate) \(fiat) (\(tokenText))"
        }
    }

    private func formatFiat(
        amount: BigUInt,
        fractionDigits: Int,
        rate: Rates.Rate,
        currency: Currency
    ) -> String? {
        let converted = RateConverter().convert(
            amount: amount,
            amountFractionLength: fractionDigits,
            rate: rate
        )
        return amountFormatter.format(
            amount: converted.amount,
            fractionDigits: converted.fractionLength,
            accessory: .currency(currency),
            isNegative: false,
            style: .compact
        )
    }

    private func formatTokenAmount(
        amount: BigUInt,
        fractionDigits: Int,
        symbol: String
    ) -> String {
        amountFormatter.format(
            amount: amount,
            fractionDigits: fractionDigits,
            accessory: .symbol(symbol),
            isNegative: false,
            style: .compact
        )
    }
}

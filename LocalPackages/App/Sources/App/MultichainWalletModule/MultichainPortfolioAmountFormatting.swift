import BigInt
import Foundation
import KeeperCore

struct MultichainPortfolioAmountFormatting {
    func lookupDouble(in map: [String: Double], currency: Currency) -> Double? {
        lookupValue(in: map, currency: currency)
    }

    func lookupString(in map: [String: String], currency: Currency) -> String? {
        lookupValue(in: map, currency: currency)
    }

    func pairedPrices(
        lhs: [String: Double],
        rhs: [String: Double],
        preferred: Currency
    ) -> (lhs: Double, rhs: Double)? {
        let currencies: [Currency] = preferred == .defaultCurrency
            ? [.defaultCurrency]
            : [preferred, .defaultCurrency]

        for currency in currencies {
            guard
                let left = valueForCodeVariants(in: lhs, code: currency.code),
                let right = valueForCodeVariants(in: rhs, code: currency.code),
                left > 0,
                right > 0
            else {
                continue
            }
            return (left, right)
        }
        return nil
    }

    func convertedAmount(for asset: MultichainAsset, currency: Currency) -> Decimal? {
        guard let price = lookupDouble(in: asset.price.prices, currency: currency) else {
            return nil
        }

        let humanBalance = decimalAmount(amount: asset.balance, fractionDigits: asset.asset.decimals)
        return humanBalance * Decimal(price)
    }

    func portfolioFiatTotalAndCurrency(
        from fiatPrice: [String: String],
        displayCurrency: Currency
    ) -> (amount: Decimal, currency: Currency)? {
        if let amount = fiatDecimal(from: fiatPrice, currencyCode: displayCurrency.code) {
            return (amount, displayCurrency)
        }
        if displayCurrency != .defaultCurrency,
           let amount = fiatDecimal(from: fiatPrice, currencyCode: Currency.defaultCurrency.code)
        {
            return (amount, Currency.defaultCurrency)
        }
        return nil
    }

    func formatAmount(
        amount: BigUInt,
        fractionDigits: Int,
        amountFormatter: AmountFormatter,
        symbol: String? = nil,
        style: AmountDisplayStyle = .compact
    ) -> String {
        let accessory: AmountAccessoryType = {
            guard let symbol, !symbol.isEmpty else {
                return .none
            }

            return .tokenSymbol(symbol)
        }()

        return amountFormatter.format(
            amount: amount,
            fractionDigits: fractionDigits,
            accessory: accessory,
            style: style
        )
    }

    private func lookupValue<T>(in map: [String: T], currency: Currency) -> T? {
        if let value = valueForCodeVariants(in: map, code: currency.code) {
            return value
        }

        if currency != .defaultCurrency {
            return valueForCodeVariants(in: map, code: Currency.defaultCurrency.code)
        }

        return nil
    }

    private func fiatDecimal(from map: [String: String], currencyCode: String) -> Decimal? {
        guard let raw = valueForCodeVariants(in: map, code: currencyCode)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !raw.isEmpty,
            let value = Decimal(string: raw)
        else { return nil }
        return value
    }

    private func valueForCodeVariants<T>(in map: [String: T], code: String) -> T? {
        for key in [code, code.uppercased(), code.lowercased()] {
            if let value = map[key] {
                return value
            }
        }
        return map.first { $0.key.caseInsensitiveCompare(code) == .orderedSame }?.value
    }

    func decimalAmount(amount: BigUInt, fractionDigits: Int) -> Decimal {
        guard let raw = Decimal(string: String(amount)) else {
            return .zero
        }
        var divisor = Decimal(1)
        for _ in 0 ..< max(0, fractionDigits) {
            divisor *= 10
        }
        return raw / divisor
    }
}

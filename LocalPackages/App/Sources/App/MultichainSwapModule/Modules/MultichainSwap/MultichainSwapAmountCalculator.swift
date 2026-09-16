import BigInt
import Foundation
import KeeperCore

struct MultichainSwapAmountCalculator {
    let amountFormatter: AmountFormatter
    let displayCurrency: Currency
    let fiatRates: MultichainSwapFiatRateResolver

    init(amountFormatter: AmountFormatter, displayCurrency: Currency) {
        self.amountFormatter = amountFormatter
        self.displayCurrency = displayCurrency
        self.fiatRates = MultichainSwapFiatRateResolver(displayCurrency: displayCurrency)
    }
}

extension MultichainSwapAmountCalculator {
    func sourceAmount(
        text: String,
        mode: MultichainSwapAmountInputMode,
        asset: MultichainAsset,
        usdFiatRate: Decimal?
    ) -> BigUInt? {
        switch mode {
        case .crypto:
            return cryptoAmount(text: text, decimals: asset.asset.decimals)
        case .fiat:
            return fiatSourceAmount(text: text, asset: asset, usdFiatRate: usdFiatRate)
        }
    }

    func cryptoAmount(text: String, decimals: Int) -> BigUInt? {
        AmountInputFormatter.amount(
            from: text,
            targetFractionalDigits: decimals
        ).amount
    }

    func parsedReceiveAmount(text: String, asset: MultichainAsset) -> BigUInt? {
        AmountInputFormatter.amount(
            from: text,
            targetFractionalDigits: asset.asset.decimals
        ).amount
    }

    func fiatSourceAmount(
        text: String,
        asset: MultichainAsset,
        usdFiatRate: Decimal?
    ) -> BigUInt? {
        let fiatUnits = AmountInputFormatter.amount(
            from: text,
            targetFractionalDigits: Self.fiatFractionDigits
        ).amount
        guard fiatUnits > 0 else {
            return fiatUnits
        }
        guard let rate = fiatRates.fiatRate(for: asset, usdFiatRate: usdFiatRate) else {
            return nil
        }
        let fiatAmount = decimalAmount(fiatUnits, decimals: Self.fiatFractionDigits) ?? .zero
        return baseUnits(
            decimalAmount: fiatAmount / rate,
            decimals: asset.asset.decimals
        )
    }
}

extension MultichainSwapAmountCalculator {
    func formattedAmount(_ baseUnits: String, asset: MultichainAsset) -> String {
        amountFormatter.format(
            amount: BigUInt(baseUnits) ?? 0,
            fractionDigits: asset.asset.decimals,
            accessory: .none,
            style: .compact
        )
    }

    func inputAmountString(
        sourceAmount: BigUInt,
        mode: MultichainSwapAmountInputMode,
        asset: MultichainAsset,
        usdFiatRate: Decimal?
    ) -> String {
        switch mode {
        case .crypto:
            return cryptoInputAmountString(
                amount: sourceAmount,
                decimals: asset.asset.decimals
            )
        case .fiat:
            guard let fiatAmount = fiatAmount(
                sourceAmount: sourceAmount,
                asset: asset,
                usdFiatRate: usdFiatRate
            ) else {
                return ""
            }
            return fiatInputAmountString(fiatAmount)
        }
    }

    func cryptoInputAmountString(amount: BigUInt, decimals: Int) -> String {
        amountFormatter.formatInput(
            amount: amount,
            fractionDigits: decimals
        )
    }

    func formatFiatAmount(_ amount: Decimal) -> String {
        amountFormatter.format(
            decimal: amount,
            accessory: .fiat(displayCurrency),
            style: .fiatBalance
        )
    }
}

extension MultichainSwapAmountCalculator {
    func sendCardRateText(
        mode: MultichainSwapAmountInputMode,
        sendAmount: String,
        asset: MultichainAsset,
        usdFiatRate: Decimal?,
        routeUsdPrice: Double? = nil
    ) -> String? {
        switch mode {
        case .crypto:
            let sourceAmount = cryptoAmount(text: sendAmount, decimals: asset.asset.decimals) ?? .zero
            guard sourceAmount > 0 else {
                return formatFiatAmount(.zero)
            }
            guard let fiatAmount = fiatAmount(
                sourceAmount: sourceAmount,
                asset: asset,
                usdFiatRate: usdFiatRate,
                fallbackUsdPrice: routeUsdPrice
            ) else {
                return nil
            }
            return formatFiatAmount(fiatAmount)
        case .fiat:
            let sourceAmount = fiatSourceAmount(
                text: sendAmount,
                asset: asset,
                usdFiatRate: usdFiatRate
            ) ?? .zero
            return amountFormatter.format(
                amount: sourceAmount,
                fractionDigits: asset.asset.decimals,
                accessory: .tokenSymbol(asset.swapDisplaySymbol),
                style: .compact
            )
        }
    }

    func receiveCardRateText(
        mode: MultichainSwapAmountInputMode,
        receiveAmount: String,
        asset: MultichainAsset,
        usdFiatRate: Decimal?,
        routeUsdPrice: Double? = nil
    ) -> String? {
        let amount = parsedReceiveAmount(text: receiveAmount, asset: asset) ?? .zero
        switch mode {
        case .crypto:
            guard amount > 0 else {
                return formatFiatAmount(.zero)
            }
            guard let fiatAmount = fiatAmount(
                sourceAmount: amount,
                asset: asset,
                usdFiatRate: usdFiatRate,
                fallbackUsdPrice: routeUsdPrice
            ) else {
                return nil
            }
            return formatFiatAmount(fiatAmount)
        case .fiat:
            return amountFormatter.format(
                amount: amount,
                fractionDigits: asset.asset.decimals,
                accessory: .tokenSymbol(asset.swapDisplaySymbol),
                style: .compact
            )
        }
    }

    /// Fiat text shown as the receive card's primary amount in fiat mode. Empty when
    /// there is nothing to convert, so the field falls back to its "0" placeholder.
    func receiveFiatDisplayAmount(
        receiveAmount: String,
        asset: MultichainAsset,
        usdFiatRate: Decimal?,
        routeUsdPrice: Double? = nil
    ) -> String {
        let amount = parsedReceiveAmount(text: receiveAmount, asset: asset) ?? .zero
        guard amount > 0,
              let fiatAmount = fiatAmount(
                  sourceAmount: amount,
                  asset: asset,
                  usdFiatRate: usdFiatRate,
                  fallbackUsdPrice: routeUsdPrice
              )
        else {
            return ""
        }
        return fiatInputAmountString(fiatAmount)
    }
}

private extension MultichainSwapAmountCalculator {
    static let fiatFractionDigits = 2
    static let roundDownBehavior = NSDecimalNumberHandler(
        roundingMode: .down,
        scale: 0,
        raiseOnExactness: false,
        raiseOnOverflow: false,
        raiseOnUnderflow: false,
        raiseOnDivideByZero: false
    )

    func fiatInputAmountString(_ amount: Decimal) -> String {
        let fiatUnits = baseUnits(
            decimalAmount: amount,
            decimals: Self.fiatFractionDigits
        ) ?? .zero
        guard fiatUnits > 0 else {
            return ""
        }
        return amountFormatter.formatInput(
            amount: fiatUnits,
            fractionDigits: Self.fiatFractionDigits
        )
    }

    func decimalAmount(_ amount: BigUInt, decimals: Int) -> Decimal? {
        amount.decimalAmount(decimals: decimals)
    }

    func fiatAmount(
        sourceAmount: BigUInt,
        asset: MultichainAsset,
        usdFiatRate: Decimal?,
        fallbackUsdPrice: Double? = nil
    ) -> Decimal? {
        guard sourceAmount > 0 else {
            return .zero
        }
        guard let rate = fiatRates.fiatRate(
            for: asset,
            usdFiatRate: usdFiatRate,
            fallbackUsdPrice: fallbackUsdPrice
        ),
            let sourceDecimal = decimalAmount(sourceAmount, decimals: asset.asset.decimals)
        else {
            return nil
        }
        return sourceDecimal * rate
    }

    func baseUnits(decimalAmount: Decimal, decimals: Int) -> BigUInt? {
        guard decimalAmount >= 0 else {
            return nil
        }
        let scaled = NSDecimalNumber(decimal: decimalAmount)
            .multiplying(byPowerOf10: Int16(max(0, decimals)))
        let rounded = scaled.rounding(accordingToBehavior: Self.roundDownBehavior)
        let integer = rounded.stringValue.components(separatedBy: ".").first ?? ""
        return BigUInt(integer)
    }
}

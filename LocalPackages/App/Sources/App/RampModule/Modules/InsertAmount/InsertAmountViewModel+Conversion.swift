import BigInt
import Foundation

extension InsertAmountViewModel {
    func fiatToTokenAmount(_ fiat: Decimal, roundingMode: NSDecimalNumber.RoundingMode, rate: Decimal) -> BigUInt {
        guard rate > 0 else { return .zero }
        let majorTokenAmount = fiat / rate
        return amountInSmallestUnits(majorTokenAmount, fractionalDigits: asset.decimals, roundingMode: roundingMode)
    }

    /// Major units of the amount field → smallest units: deposit = fiat (`currency.fractionalDigits`), withdraw = token (`asset.decimals`); matches `inputDecimals`.
    func fiatToSmallestUnits(_ fiat: Decimal, roundingMode: NSDecimalNumber.RoundingMode) -> BigUInt {
        amountInSmallestUnits(fiat, fractionalDigits: inputDecimals, roundingMode: roundingMode)
    }

    /// `value` in major units (e.g. whole TON) → smallest units using `fractionalDigits`.
    private func amountInSmallestUnits(
        _ value: Decimal,
        fractionalDigits: Int,
        roundingMode: NSDecimalNumber.RoundingMode
    ) -> BigUInt {
        let multiplier = Decimal(pow(10.0, Double(fractionalDigits)))
        let scaled = value * multiplier
        let rounded = (scaled as NSDecimalNumber).rounding(
            accordingToBehavior: NSDecimalNumberHandler(
                roundingMode: roundingMode,
                scale: 0,
                raiseOnExactness: false,
                raiseOnOverflow: false,
                raiseOnUnderflow: false,
                raiseOnDivideByZero: false
            )
        )
        return BigUInt(rounded.stringValue) ?? 0
    }
}

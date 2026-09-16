import BigInt
import Foundation

public struct RateConverter {
    public init() {}

    public func convert(
        amount: Int64,
        amountFractionLength: Int,
        rate: Rates.Rate
    ) -> (amount: BigUInt, fractionLength: Int) {
        let stringAmount = String(amount)
        let bigIntAmount = BigUInt(stringLiteral: stringAmount)
        return convert(
            amount: bigIntAmount,
            amountFractionLength: amountFractionLength,
            rate: rate
        )
    }

    public func convert(
        amount: BigUInt,
        amountFractionLength: Int,
        rate: Rates.Rate
    ) -> (amount: BigUInt, fractionLength: Int) {
        let rateFractionLength = max(Int16(-rate.rate.exponent), 0)
        let ratePlain = NSDecimalNumber(decimal: rate.rate)
            .multiplying(byPowerOf10: rateFractionLength)
        let rateBigInt = BigUInt(stringLiteral: ratePlain.stringValue)

        let fractionLength = Int(rateFractionLength) + amountFractionLength
        let converted = amount * rateBigInt
        return (amount: converted, fractionLength: fractionLength)
    }

    /// `amount` in `amountFractionLength` decimals × `rate` (dest major / source major)
    /// → result in `targetFractionLength` decimals.
    public func convert(
        amount: BigUInt,
        amountFractionLength: Int,
        rate: NSDecimalNumber,
        targetFractionLength: Int
    ) -> BigUInt {
        convertByScaling(
            amount: amount,
            amountFractionLength: amountFractionLength,
            targetFractionLength: targetFractionLength
        ) { amountMajor in
            amountMajor.multiplying(by: rate)
        }
    }

    public func convertFromCurrency(
        amount: BigUInt,
        amountFractionLength: Int,
        rate: Rates.Rate
    ) -> BigUInt {
        let amountDecimalNumber = NSDecimalNumber(string: String(amount))
        let rateDecimalNumber = NSDecimalNumber(decimal: rate.rate)
        let converted = amountDecimalNumber.dividing(by: rateDecimalNumber)
        guard let convertedIntegerPart = converted.stringValue.components(separatedBy: ".").first,
              let result = BigUInt(convertedIntegerPart)
        else {
            return 0
        }
        return result
    }

    /// `amount` in `amountFractionLength` decimals ÷ `rate` (dest major / source major)
    /// → result in `targetFractionLength` decimals.
    public func convertFromCurrency(
        amount: BigUInt,
        amountFractionLength: Int,
        rate: NSDecimalNumber,
        targetFractionLength: Int
    ) -> BigUInt {
        convertByScaling(
            amount: amount,
            amountFractionLength: amountFractionLength,
            targetFractionLength: targetFractionLength
        ) { amountMajor in
            amountMajor.dividing(by: rate)
        }
    }

    public func convertToDecimal(
        amount: BigUInt,
        amountFractionLength: Int,
        rate: Rates.Rate
    ) -> Decimal {
        let decimalAmount = NSDecimalNumber(string: String(amount))
            .multiplying(byPowerOf10: Int16(-amountFractionLength))
        return decimalAmount.decimalValue * rate.rate
    }

    public func convertJetton(
        amount: BigUInt,
        fromRate: Rates.Rate,
        toRate: Rates.Rate
    ) -> BigUInt {
        let amountDecimalNumber = NSDecimalNumber(string: String(amount))
        let fromRateDecimalNumber = NSDecimalNumber(decimal: fromRate.rate)
        let toRateDecimalNumber = NSDecimalNumber(decimal: toRate.rate)

        let fiatValue = amountDecimalNumber.multiplying(by: fromRateDecimalNumber)
        let finalAmount = fiatValue.dividing(by: toRateDecimalNumber, withBehavior: NSDecimalNumberHandler.roundBehaviour)

        guard let convertedIntegerPart = finalAmount.stringValue.components(separatedBy: ".").first,
              let result = BigUInt(convertedIntegerPart)
        else {
            return 0
        }
        return result
    }

    private func convertByScaling(
        amount: BigUInt,
        amountFractionLength: Int,
        targetFractionLength: Int,
        transform: (NSDecimalNumber) -> NSDecimalNumber
    ) -> BigUInt {
        let amountMajor = NSDecimalNumber(string: String(amount))
            .multiplying(byPowerOf10: Int16(-amountFractionLength))
        let convertedMajor = transform(amountMajor)
        let convertedScaled = convertedMajor.multiplying(byPowerOf10: Int16(targetFractionLength))
        let rounded = convertedScaled.rounding(accordingToBehavior: NSDecimalNumberHandler.roundBehaviour)
        guard rounded.compare(NSDecimalNumber.zero) != .orderedAscending,
              let result = BigUInt(rounded.stringValue)
        else {
            return 0
        }
        return result
    }
}

private extension NSDecimalNumberHandler {
    static var roundBehaviour: NSDecimalNumberHandler {
        return NSDecimalNumberHandler(
            roundingMode: .plain,
            scale: 0,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: false
        )
    }
}

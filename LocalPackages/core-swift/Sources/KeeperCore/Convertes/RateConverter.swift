import Foundation
import BigInt

public struct RateConverter {
  
  public init() {}
  
  public func convert(amount: Int64,
                      amountFractionLength: Int,
                      rate: Rates.Rate) -> (amount: BigUInt, fractionLength: Int) {
    let stringAmount = String(amount)
    let bigIntAmount = BigUInt(stringLiteral: stringAmount)
    return convert(
      amount: bigIntAmount,
      amountFractionLength: amountFractionLength,
      rate: rate)
  }
  
  public func convert(amount: BigUInt,
                      amountFractionLength: Int,
                      rate: Rates.Rate) -> (amount: BigUInt, fractionLength: Int) {
    let rateFractionLength = max(Int16(-rate.rate.exponent), 0)
    let ratePlain = NSDecimalNumber(decimal: rate.rate)
      .multiplying(byPowerOf10: rateFractionLength)
    let rateBigInt = BigUInt(stringLiteral: ratePlain.stringValue)
    
    let fractionLength = Int(rateFractionLength) + amountFractionLength
    let converted = amount * rateBigInt
    return (amount: converted, fractionLength: fractionLength)
  }
  
  public func convertFromCurrency(amount: BigUInt,
                                  amountFractionLength: Int,
                                  rate: Rates.Rate) -> BigUInt {
    let amountDecimalNumber = NSDecimalNumber(string: String(amount))
    let rateDecimalNumber = NSDecimalNumber(decimal: rate.rate)
    let converted = amountDecimalNumber.dividing(by: rateDecimalNumber)
    guard let convertedIntegerPart = converted.stringValue.components(separatedBy: ".").first,
    let result = BigUInt(convertedIntegerPart) else {
      return 0
    }
    return result
  }
  
  public func convertToDecimal(amount: BigUInt,
                               amountFractionLength: Int,
                               rate: Rates.Rate) -> Decimal {
    let decimalAmount = NSDecimalNumber(string: String(amount))
      .multiplying(byPowerOf10: Int16(-amountFractionLength))
    let converted = decimalAmount.decimalValue * rate.rate
    return converted
  }
}

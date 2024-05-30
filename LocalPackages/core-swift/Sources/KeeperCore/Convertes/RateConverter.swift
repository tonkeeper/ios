import Foundation
import BigInt

public struct RateConverter {
  public init() {}
  
  func convert(amount: Int64,
               amountFractionLength: Int,
               rate: Rates.Rate) -> (amount: BigUInt, fractionLength: Int) {
    let stringAmount = String(amount)
    let bigIntAmount = BigUInt(stringLiteral: stringAmount)
    return convert(
      amount: bigIntAmount,
      amountFractionLength: amountFractionLength,
      rate: rate)
  }
  
  func convert(amount: BigUInt,
               amountFractionLength: Int,
               rate: Rates.Rate) -> (amount: BigUInt, fractionLength: Int) {
    return convert(
      amount: amount,
      amountFractionLength: amountFractionLength,
      rate: rate.rate
    )
  }
  
  public func convert(amount: BigUInt,
               amountFractionLength: Int,
               rate: Decimal) -> (amount: BigUInt, fractionLength: Int) {
    let rateFractionLength = max(Int16(-rate.exponent), 0)
    let ratePlain = NSDecimalNumber(decimal: rate)
      .multiplying(byPowerOf10: rateFractionLength)
    let rateBigInt = BigUInt(stringLiteral: ratePlain.stringValue)
    
    let fractionLength = Int(rateFractionLength) + amountFractionLength
    let converted = amount * rateBigInt
    return (amount: converted, fractionLength: fractionLength)
  }
}

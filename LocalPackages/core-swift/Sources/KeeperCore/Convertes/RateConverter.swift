import Foundation
import BigInt

struct RateConverter {
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
    let rateFractionLength = max(Int16(-rate.rate.exponent), 0)
    let ratePlain = NSDecimalNumber(decimal: rate.rate)
      .multiplying(byPowerOf10: rateFractionLength)
    let rateBigInt = BigUInt(stringLiteral: ratePlain.stringValue)
    
    let fractionLength = Int(rateFractionLength) + amountFractionLength
    let converted = amount * rateBigInt
    return (amount: converted, fractionLength: fractionLength)
  }
}

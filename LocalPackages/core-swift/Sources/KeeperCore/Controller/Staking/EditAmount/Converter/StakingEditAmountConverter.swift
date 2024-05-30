import Foundation
import TonSwift
import BigInt
import TKUIKit

final class StakingEditAmountConverter {
  private let rateConverter: RateConverter
  
  init(rateConverter: RateConverter) {
    self.rateConverter = rateConverter
  }
  
  func inputStringToAmount(input: String, targetFractionalDigits: Int) -> (amount: BigUInt, fractionalDigits: Int) {
    guard !input.isEmpty else { return (0, targetFractionalDigits) }
    let fractionalSeparator: String = .fractionalSeparator ?? ""
    let components = input.components(separatedBy: fractionalSeparator)
    guard components.count < 3 else {
      return (0, targetFractionalDigits)
    }
    
    var fractionalDigits = 0
    if components.count == 2 {
        let fractionalString = components[1]
        fractionalDigits = fractionalString.count
    }
    let zeroString = String(repeating: "0", count: max(0, targetFractionalDigits - fractionalDigits))
    let bigIntValue = BigUInt(stringLiteral: components.joined() + zeroString)
    return (bigIntValue, targetFractionalDigits)
  }
  
  func tokenAmountToCurrency(amount: BigUInt, token: Token, rate: Rates.Rate?) -> (BigUInt, Int) {
    if let rate {
      return rateConverter.convert(
        amount: amount,
        amountFractionLength: token.fractionDigits,
        rate: rate
      )
    } else {
      return (0, 2)
    }
  }
  
  func currencyAmountToToken(
    amount: BigUInt,
    fractionalDigits: Int,
    rate: Rates.Rate?,
    currency: Currency
  ) -> (BigUInt, Int) {
    if let rate {
      let reversedRate = Rates.Rate(currency: currency, rate: 1/rate.rate, diff24h: nil)
      return rateConverter.convert(amount: amount, amountFractionLength: fractionalDigits, rate: reversedRate)
    } else {
      return (0, fractionalDigits)
    }
  }
  
  func apy(_ apy: Decimal, investing: BigUInt) -> BigUInt {
    let apyFractionLength = max(Int(-apy.exponent), 0)
    let apyPlain = NSDecimalNumber(decimal: apy).multiplying(byPowerOf10: Int16(apyFractionLength))
    let apyBigInt = BigUInt(stringLiteral: apyPlain.stringValue)
  
    let scalingFactor = BigUInt(100) * BigUInt(10).power(apyFractionLength)
    
    return investing * apyBigInt / scalingFactor
  }
}

private extension String {
  static var fractionalSeparator: String? {
    Locale.current.decimalSeparator
  }
}

import Foundation
import BigInt

public struct BatteryCalculation {
  private let configuration: Configuration
  
  init(configuration: Configuration) {
    self.configuration = configuration
  }
  
  public func calculateCharges(tonAmount: BigUInt) -> Int? {
    guard let batteryMeanFees = configuration.batteryMeanFeesDecimaNumber(isTestnet: false) else { return nil }
    let convertedAmount = NSDecimalNumber(
      mantissa: UInt64(tonAmount),
      exponent: -Int16(TonInfo.fractionDigits),
      isNegative: false)
    let chargesCountDecimal = convertedAmount.dividing(by: batteryMeanFees)
    let chargesCountRounded = chargesCountDecimal.rounding(
      accordingToBehavior: NSDecimalNumberHandler(
        roundingMode: .up,
        scale: 0,
        raiseOnExactness: false,
        raiseOnOverflow: false,
        raiseOnUnderflow: false,
        raiseOnDivideByZero: false)
    )
    return Int(truncating: chargesCountRounded)
  }
}

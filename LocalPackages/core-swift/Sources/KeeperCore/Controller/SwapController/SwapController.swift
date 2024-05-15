import Foundation
import BigInt

public final class SwapController {
  
  let amountFormatter: AmountFormatter
  
  init(amountFormatter: AmountFormatter) {
    self.amountFormatter = amountFormatter
  }
  
  public func start() async {
    
  }
  
  public func convertStringToAmount(string: String, targetFractionalDigits: Int) -> (value: BigUInt, fractionalDigits: Int) {
    guard !string.isEmpty else { return (0, targetFractionalDigits) }
    let fractionalSeparator: String = .fractionalSeparator ?? ""
    let components = string.components(separatedBy: fractionalSeparator)
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
  
  public func convertAmountToString(amount: BigUInt, fractionDigits: Int) -> String {
    return amountFormatter.formatAmount(
      amount,
      fractionDigits: fractionDigits,
      maximumFractionDigits: TonInfo.fractionDigits
    )
  }
}

private extension String {
  static let groupSeparator = " "
  static var fractionalSeparator: String? {
    Locale.current.decimalSeparator
  }
}

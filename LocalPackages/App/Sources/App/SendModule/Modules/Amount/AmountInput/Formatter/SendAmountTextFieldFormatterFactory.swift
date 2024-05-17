
import Foundation

enum SendAmountTextFieldFormatterFactory {

  static func make(groupingSeparator: String = " ") -> SendAmountTextFieldFormatter {
    let numberFormatter = NumberFormatter()
    numberFormatter.groupingSeparator = groupingSeparator
    numberFormatter.groupingSize = 3
    numberFormatter.usesGroupingSeparator = true
    numberFormatter.decimalSeparator = Locale.current.decimalSeparator
    numberFormatter.maximumIntegerDigits = 16
    numberFormatter.roundingMode = .down
    let amountInputFormatController = SendAmountTextFieldFormatter(
      currencyFormatter: numberFormatter
    )
    return amountInputFormatController
  }
}

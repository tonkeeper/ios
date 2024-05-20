import Foundation

public final class FormattersAssembly {
  public func amountFormatter(
    bigIntAmountFormatter: BigIntAmountFormatter = BigIntAmountFormatter()
  ) -> AmountFormatter {
    AmountFormatter(bigIntFormatter: bigIntAmountFormatter)
  }
  
  public func bigIntAmountFormatter(
    groupSeparator: String = " ",
    fractionalSeparator: String? = Locale.current.decimalSeparator
  ) -> BigIntAmountFormatter {
    BigIntAmountFormatter(groupSeparator: groupSeparator, fractionalSeparator: fractionalSeparator)
  }
  
  public var shortNumberFormatter: NumberFormatter {
    let formatter = NumberFormatter()
    formatter.groupingSeparator = " "
    formatter.groupingSize = 3
    formatter.usesGroupingSeparator = true
    formatter.decimalSeparator = Locale.current.decimalSeparator
    formatter.maximumFractionDigits = 2
    return formatter
  }
  
  public var decimalAmountFormatter: DecimalAmountFormatter {
    DecimalAmountFormatter(numberFormatter: shortNumberFormatter)
  }
  
  public var dateFormatter: DateFormatter {
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale.current
    return dateFormatter
  }
}

import Foundation

public final class FormattersAssembly {
  public var amountFormatter: AmountFormatter {
    AmountFormatter(bigIntFormatter: bigIntAmountFormatter)
  }
  
  public var amountNewFormatter: AmountNewFormatter {
    AmountNewFormatter(bigIntFormatter: bigIntAmountFormatter)
  }
  
  public var bigIntAmountFormatter: BigIntAmountFormatter {
    BigIntAmountFormatter()
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
  
  public var shortNumberNewFormatter: NumberFormatter {
    let formatter = shortNumberFormatter
    formatter.groupingSeparator = FormattersConstants.groupingSeparator
    formatter.decimalSeparator = FormattersConstants.fractionalSeparator
    return formatter
  }
  
  public var decimalAmountNewFormatter: DecimalAmountFormatter {
    DecimalAmountFormatter(numberFormatter: shortNumberNewFormatter)
  }
  
  public var dateFormatter: DateFormatter {
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale.current
    return dateFormatter
  }
}

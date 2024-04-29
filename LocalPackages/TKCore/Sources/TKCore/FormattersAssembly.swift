import Foundation
import KeeperCore

public struct FormattersAssembly {
  public func chartFormatter(dateFormatter: DateFormatter, decimalAmountFormatter: DecimalAmountFormatter) -> ChartFormatter {
    ChartFormatter(
      dateFormatter: dateFormatter,
      decimalAmountFormatter: decimalAmountFormatter
    )
  }
}

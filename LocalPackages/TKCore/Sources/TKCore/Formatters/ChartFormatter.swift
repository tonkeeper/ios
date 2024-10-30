import Foundation
import KeeperCore

public final class ChartFormatter {
  private let decimalAmountFormatter: DecimalAmountFormatter
  private let dateFormatter: DateFormatter
  
  init(dateFormatter: DateFormatter, decimalAmountFormatter: DecimalAmountFormatter) {
    self.dateFormatter = dateFormatter
    self.dateFormatter.locale = Locale.current
    self.decimalAmountFormatter = decimalAmountFormatter
  }
  
  public func formatInformationTimeInterval(_ timeInterval: TimeInterval,
                                            period: Period) -> String? {
    let dateFormat: String
    switch period {
    case .hour: dateFormat = "E',' d MMM HH:mm"
    case .day: dateFormat = "E',' d MMM HH:mm"
    case .week: dateFormat = "E',' d MMM HH:mm"
    case .month: dateFormat = "E',' d MMM"
    case .halfYear: dateFormat = "yyyy E',' d MMM"
    case .year: dateFormat = "yyyy E',' d MMM"
    }
    
    dateFormatter.dateFormat = dateFormat
    
    return dateFormatter.string(from: Date(timeIntervalSince1970: timeInterval))
  }
  
  public func formatXAxis(timeInterval: TimeInterval, period: Period) -> String? {
    let dateFormat: String
    switch period {
    case .hour: dateFormat = "HH:mm"
    case .day: dateFormat = "HH:mm"
    case .week: dateFormat = "dd MMM"
    case .month: dateFormat = "dd MMM"
    case .halfYear: dateFormat = "dd MMM"
    case .year: dateFormat = "dd MMM"
    }
    
    dateFormatter.dateFormat = dateFormat
    
    return dateFormatter.string(from: Date(timeIntervalSince1970: timeInterval))
  }
  
  public func mapMaxMinValue(value: Double, currency: Currency) -> String {
    decimalAmountFormatter.format(
      amount: Decimal(floatLiteral: value),
      maximumFractionDigits: 2,
      currency: currency
    )
  }
  
  public func formatValue(coordinate: Coordinate, currency: Currency) -> String {
    decimalAmountFormatter.format(
      amount: Decimal(coordinate.y),
      significantFractionDigits: 4,
      currency: currency)
  }
  
  public func formatDiff(diff: Double) -> String {
    var formatted = String(format: "%.2f% %", abs(diff))
    if diff > 0 {
      formatted = "+ \(formatted)"
    } else if diff < 0 {
      formatted = "- \(formatted)"
    }
    return formatted
  }
  
  public func formatCurrencyDiff(diff: Double, currency: Currency) -> String {
    decimalAmountFormatter.format(
      amount: Decimal(abs(diff)),
      significantFractionDigits: 4,
      currency: currency)
  }
}

extension String {
  enum Symbol {
    static let minus = "\u{2212}"
    static let plus = "\u{002B}"
    static let shortSpace = "\u{2009}"
    static let almostEqual = "\u{2248}"
    static let middleDot = "\u{00B7}"
  }
}



import Foundation
import TKLocalize

public enum Period: CaseIterable {
  case hour
  case day
  case week
  case month
  case halfYear
  case year
  
  public var startDate: Date {
    let calendar = Calendar.current
    switch self {
    case .day:
      return calendar.date(byAdding: DateComponents(day: -1), to: Date())!
    case .halfYear:
      return calendar.date(byAdding: DateComponents(month: -6), to: Date())!
    case .hour:
      return calendar.date(byAdding: DateComponents(hour: -1), to: Date())!
    case .month:
      return calendar.date(byAdding: DateComponents(month: -1), to: Date())!
    case .week:
      return calendar.date(byAdding: DateComponents(day: -7), to: Date())!
    case .year:
      return calendar.date(byAdding: DateComponents(year: -1), to: Date())!
    }
  }
  
  public var endDate: Date {
    Date()
  }
  
  var stringValue: String {
    switch self {
    case .hour: return "1H"
    case .day: return "1D"
    case .week: return "7D"
    case .month: return "1M"
    case .halfYear: return "6M"
    case .year: return "1Y"
    }
  }
  
  public var title: String {
    switch self {
    case .hour: return TKLocales.Periods.hour
    case .day: return TKLocales.Periods.day
    case .week: return TKLocales.Periods.week
    case .month: return TKLocales.Periods.month
    case .halfYear: return TKLocales.Periods.half_year
    case .year: return TKLocales.Periods.year
    }
  }
}

import Foundation

public enum BuySellOperationType {
  case buy
  case sell
}

extension BuySellOperationType {
  var fiatCategoryType: FiatMethodCategory.CategoryType {
    switch self {
    case .buy:
      return .buy
    case .sell:
      return .sell
    }
  }
}

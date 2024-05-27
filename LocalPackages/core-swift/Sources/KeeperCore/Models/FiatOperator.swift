import Foundation
import BigInt

public struct FiatOperator: Identifiable {
  public struct InfoButton {
    public let title: String
    public let url: URL?
  }
  
  public let id: String
  public let title: String
  public let description: String
  public var badge: String?
  public let iconURL: URL?
  public let actionTemplateURL: String?
  public let infoButtons: [InfoButton]
  public let rate: Decimal?
  public let formattedRate: String
  public let minTonBuyAmount: BigUInt?
  public let minTonSellAmount: BigUInt?
  
  public init(id: String,
             title: String,
             description: String,
             badge: String?,
             iconURL: URL?,
             actionTemplateURL: String?,
             infoButtons: [InfoButton],
             rate: Decimal?,
             formattedRate: String,
             minTonBuyAmount: BigUInt?,
             minTonSellAmount: BigUInt?) {
    self.id = id
    self.title = title
    self.description = description
    self.badge = badge
    self.iconURL = iconURL
    self.actionTemplateURL = actionTemplateURL
    self.infoButtons = infoButtons
    self.rate = rate
    self.formattedRate = formattedRate
    self.minTonBuyAmount = minTonBuyAmount
    self.minTonSellAmount = minTonSellAmount
  }
}

public enum FiatOperatorCategory {
  case buy
  case sell
}

extension FiatOperatorCategory {
  var fiatMethodCategory: FiatMethodCategory.CategoryType {
    switch self {
    case .buy:
      return .buy
    case .sell:
      return .sell
    }
  }
}

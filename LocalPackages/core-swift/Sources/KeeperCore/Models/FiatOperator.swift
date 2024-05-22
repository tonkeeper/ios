import Foundation

public struct FiatOperator: Identifiable {
  public struct InfoButton {
    public let title: String
    public let url: URL?
  }
  
  public let id: String
  public let title: String
  public let description: String
  public let rate: Decimal
  public let formattedRate: String
  public var badge: String?
  public let iconURL: URL?
  public let actionTemplateURL: String?
  public let infoButtons: [InfoButton]
  
  public init(id: String, 
              title: String,
              description: String,
              rate: Decimal,
              formattedRate: String,
              badge: String?,
              iconURL: URL?,
              actionTemplateURL: String?,
              infoButtons: [InfoButton]) {
    self.id = id
    self.title = title
    self.description = description
    self.rate = rate
    self.formattedRate = formattedRate
    self.badge = badge
    self.iconURL = iconURL
    self.actionTemplateURL = actionTemplateURL
    self.infoButtons = infoButtons
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

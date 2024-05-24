import UIKit

public struct TokenListItemsModel {
  public let items: [Item]
  
  public init(items: [Item]) {
    self.items = items
  }
}

public extension TokenListItemsModel {
  struct Item {
    public let identifier: String
    public let image: ImageModel
    public let kind: AssetKind
    public let symbol: String
    public let displayName: String
    public let badge: String?
    public var amount: String?
    public var convertedAmount: String?
    
    public init(identifier: String,
                image: ImageModel,
                kind: AssetKind,
                symbol: String,
                displayName: String,
                badge: String?,
                amount: String?,
                convertedAmount: String?) {
      self.identifier = identifier
      self.image = image
      self.kind = kind
      self.symbol = symbol
      self.displayName = displayName
      self.badge = badge
      self.amount = amount
      self.convertedAmount = convertedAmount
    }
  }
}

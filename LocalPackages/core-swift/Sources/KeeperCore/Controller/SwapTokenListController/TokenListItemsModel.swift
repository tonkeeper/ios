import UIKit

public struct TokenListItemsModel {
  public let items: [Item]
  
  public init(items: [Item]) {
    self.items = items
  }
}

public extension TokenListItemsModel {
  struct Item {
    public enum Image {
      case image(UIImage)
      case asyncImage(URL?)
    }
    
    public let identifier: String
    public let image: Image
    public let symbol: String
    public let displayName: String
    public let badge: String?
    public let amount: String?
    public let convertedAmount: String?
    
    public init(identifier: String,
                image: Image,
                symbol: String,
                displayName: String,
                badge: String?,
                amount: String?,
                convertedAmount: String?) {
      self.identifier = identifier
      self.image = image
      self.symbol = symbol
      self.displayName = displayName
      self.badge = badge
      self.amount = amount
      self.convertedAmount = convertedAmount
    }
  }
}

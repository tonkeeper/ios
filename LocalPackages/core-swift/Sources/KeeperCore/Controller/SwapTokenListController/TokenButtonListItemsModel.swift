import UIKit

public struct TokenButtonListItemsModel {
  public let items: [Item]
  
  public init(items: [Item]) {
    self.items = items
  }
}

public extension TokenButtonListItemsModel {
  struct Item {
    public let identifier: String
    public let image: ImageModel
    public let kind: AssetKind
    public let symbol: String
  }
}

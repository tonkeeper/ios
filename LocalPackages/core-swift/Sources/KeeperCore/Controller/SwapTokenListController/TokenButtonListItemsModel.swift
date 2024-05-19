import UIKit

public struct TokenButtonListItemsModel {
  public let items: [Item]
  
  public init(items: [Item]) {
    self.items = items
  }
}

public extension TokenButtonListItemsModel {
  struct Item {
    public let asset: SwapAsset
    public let image: ImageModel
    
    public var identifier: String {
      asset.contractAddress.toString()
    }
    
    public var kind: AssetKind {
      asset.kind
    }
    
    public var symbol: String {
      asset.symbol
    }
  }
}

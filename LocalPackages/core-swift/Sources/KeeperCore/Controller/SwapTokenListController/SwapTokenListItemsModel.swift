import UIKit
import TonSwift

public struct SwapTokenListItemsModel {
  public let items: [Item]
  
  public init(items: [Item]) {
    self.items = items
  }
}

public extension SwapTokenListItemsModel {
  struct Item {
    public let asset: SwapAsset
    public let image: ImageModel
    public let badge: String?
    public var amount: String?
    public var convertedAmount: String?
    
    public var identifier: String {
      asset.contractAddress.toString()
    }
    
    public var kind: AssetKind {
      asset.kind
    }
    
    public var symbol: String {
      asset.symbol
    }
    
    public var displayName: String {
      asset.displayName
    }
  }
}

public struct SwapAsset {
  public var contractAddress: Address
  public var kind: AssetKind
  public var symbol: String
  public var displayName: String
  public var fractionDigits: Int
  public var imageUrl: URL?
  
  public init(contractAddress: Address, kind: AssetKind, symbol: String, displayName: String, fractionDigits: Int, imageUrl: URL? = nil) {
    self.contractAddress = contractAddress
    self.kind = kind
    self.symbol = symbol
    self.displayName = displayName
    self.fractionDigits = fractionDigits
    self.imageUrl = imageUrl
  }
}

extension SwapAsset: Equatable {
  public static func == (lhs: SwapAsset, rhs: SwapAsset) -> Bool {
    return lhs.contractAddress == rhs.contractAddress
    && lhs.kind == rhs.kind
    && lhs.symbol == rhs.symbol
    && lhs.displayName == rhs.displayName
  }
}

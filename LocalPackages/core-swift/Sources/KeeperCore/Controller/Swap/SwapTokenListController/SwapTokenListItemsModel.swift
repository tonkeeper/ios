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

public enum SwapAsset {
  case ton(AssetInfo)
  case jetton(AssetInfo)
  case unknown(AssetInfo)
  
  var assetInfo: AssetInfo {
    switch self {
    case .ton(let info), .jetton(let info), .unknown(let info):
      return info
    }
  }
  
  public var kind: AssetKind {
    assetInfo.kind
  }
  public var contractAddress: Address {
    assetInfo.contractAddress
  }
  public var symbol: String {
    assetInfo.symbol
  }
  public var displayName: String {
    assetInfo.displayName
  }
  public var fractionDigits: Int {
    assetInfo.fractionDigits
  }
  public var imageUrl: URL? {
    assetInfo.imageUrl
  }
  
  public init(kind: AssetKind,
              contractAddress: Address,
              symbol: String,
              displayName: String,
              fractionDigits: Int,
              isWhitelisted: Bool,
              imageUrl: URL? = nil) {
    let assetInfo = AssetInfo(
      kind: kind,
      contractAddress: contractAddress,
      symbol: symbol,
      displayName: displayName,
      fractionDigits: fractionDigits,
      isWhitelisted: isWhitelisted,
      imageUrl: imageUrl
    )
    
    switch kind {
    case .ton:
      self = .ton(assetInfo)
    case .jetton:
      self = .jetton(assetInfo)
    case .unknown:
      self = .unknown(assetInfo)
    }
  }
}

extension SwapAsset: Equatable {
  public static func == (lhs: SwapAsset, rhs: SwapAsset) -> Bool {
    return lhs.assetInfo == rhs.assetInfo
  }
}

public struct AssetInfo: Equatable {
  public var kind: AssetKind
  public var contractAddress: Address
  public var symbol: String
  public var displayName: String
  public var fractionDigits: Int
  public var isWhitelisted: Bool
  public var imageUrl: URL?
}

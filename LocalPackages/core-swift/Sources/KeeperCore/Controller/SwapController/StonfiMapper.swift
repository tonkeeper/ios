import Foundation
import TonSwift

struct StonfiMapper {
  func mapStonfiAsset(_ asset: StonfiAsset) -> SwapAsset? {
    var imageUrl: URL?
    if let imageUrlString = asset.imageUrl  {
      imageUrl = URL(string: imageUrlString)
    }
    
    let assetKind = AssetKind(fromString: asset.kind)
    
    let displayName: String
    if assetKind == .ton, asset.displayName == TonInfo.symbol {
      displayName = TonInfo.name
    } else {
      displayName = asset.displayName ?? ""
    }
    
    guard let contractAddress = try? Address.parse(asset.contractAddress) else { return nil }
    
    return SwapAsset(
      contractAddress: contractAddress,
      kind: assetKind,
      symbol: asset.symbol,
      displayName: displayName,
      fractionDigits: asset.decimals,
      imageUrl: imageUrl
    )
  }
}

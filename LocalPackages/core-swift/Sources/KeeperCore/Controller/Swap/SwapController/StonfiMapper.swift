import Foundation
import TonSwift

struct StonfiMapper {
  func mapStonfiAsset(_ asset: StonfiAsset) -> SwapAsset? {
    guard let contractAddress = try? Address.parse(asset.contractAddress) else { return nil }
    
    let imageUrl = mapImageUrlString(asset.imageUrl)
    let assetKind = AssetKind(fromString: asset.kind)
    let displayName = getDisplayName(for: asset, kind: assetKind)
    let tags = asset.tags ?? []
    let isWhitelisted = tags.contains(where: { $0.lowercased() == .tagWhitelisted })

    return SwapAsset(
      kind: assetKind,
      contractAddress: contractAddress,
      symbol: asset.symbol,
      displayName: displayName,
      fractionDigits: asset.decimals,
      isWhitelisted: isWhitelisted,
      imageUrl: imageUrl
    )
  }
  
  func mapImageUrlString(_ imageUrlString: String?) -> URL? {
    guard let imageUrlString else { return nil }
    return URL(string: imageUrlString)
  }
  
  func getDisplayName(for asset: StonfiAsset, kind assetKind: AssetKind) -> String {
    if assetKind == .ton, asset.displayName == TonInfo.symbol {
      return TonInfo.name
    } else {
      return asset.displayName ?? ""
    }
  }
}

private extension String {
  static let tagWhitelisted = "whitelisted"
}

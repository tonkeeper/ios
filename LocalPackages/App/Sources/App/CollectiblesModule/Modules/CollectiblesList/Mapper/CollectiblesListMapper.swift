import UIKit
import KeeperCore
import TKCore
import TKLocalize

struct CollectiblesListMapper {
  let imageLoader = ImageLoader()

  func map(nfts: [NFT], isSecureMode: Bool) -> [CollectibleCollectionViewCell.Model] {
    nfts.map { nft in
      map(nft: nft, isSecureMode: isSecureMode)
    }
  }
  
  func map(nft: NFT, isSecureMode: Bool) -> CollectibleCollectionViewCell.Model {
    let title: String = isSecureMode ? "* * * *" : nft.name ?? nft.address.toString(bounceable: true)
    
    let subtitle: NSAttributedString?
    switch nft.trust {
    case .none, .blacklist, .unknown:
      subtitle = TKLocales.Purchases.unverified.withTextStyle(
        .body3,
        color: .Accent.orange,
        alignment: .left,
        lineBreakMode: .byTruncatingTail
      )
    case .whitelist, .graylist:
      let string: String? = {
        if isSecureMode {
          return .secureModeValueShort
        }
        if let collection = nft.collection {
          return (collection.name == nil || collection.name?.isEmpty == true) ? TKLocales.Purchases.unnamedCollection : collection.name
        } else {
          return TKLocales.Purchases.unnamedCollection
        }
      }()
      subtitle = string?.withTextStyle(
        .body3,
        color: .Text.secondary,
        alignment: .left,
        lineBreakMode: .byTruncatingTail
      )
    }
    
    return CollectibleCollectionViewCell.Model(
      identifier: nft.address.toRaw(),
      imageDownloadTask: ImageDownloadTask(closure: { [weak imageLoader] imageView, size, cornerRadius in
        imageLoader?.loadImage(url: nft.preview.size500, imageView: imageView, size: size, cornerRadius: cornerRadius)
      }),
      title: title,
      subtitle: subtitle,
      isOnSale: nft.sale != nil,
      isBlurVisible: isSecureMode
    )
  }
}

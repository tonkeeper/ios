import UIKit
import KeeperCore
import TKCore
import TKLocalize

struct CollectiblesListMapper {
  let imageLoader = ImageLoader()

  func map(nfts: [NFT]) -> [CollectibleCollectionViewCell.Model] {
    nfts.map { nft in
      map(nft: nft)
    }
  }
  
  func map(nft: NFT) -> CollectibleCollectionViewCell.Model {
    let title = nft.name ?? nft.address.toString(bounceable: true)
    
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
      let string = {
        if let collection = nft.collection {
            return (collection.name == nil || collection.name?.isEmpty == true) ? TKLocales.Purchases.unnamed_collection : collection.name
        } else {
          return TKLocales.Purchases.unnamed_collection
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
      isOnSale: nft.sale != nil
    )
  }
}

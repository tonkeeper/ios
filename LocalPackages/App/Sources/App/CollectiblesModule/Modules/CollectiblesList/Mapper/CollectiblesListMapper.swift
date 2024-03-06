import UIKit
import KeeperCore
import TKCore

struct CollectiblesListMapper {
  let imageLoader = ImageLoader()
  func map(nftModels: [NFTModel]) -> [CollectibleCollectionViewCell.Model] {
    nftModels.map { model in
      CollectibleCollectionViewCell.Model(
        identifier: model.address.toRaw(),
        imageDownloadTask: ImageDownloadTask(closure: { [weak imageLoader] imageView, size, cornerRadius in
          imageLoader?.loadImage(url: model.imageUrl, imageView: imageView, size: size, cornerRadius: cornerRadius)
        }),
        title: model.name,
        subtitle: model.collectionName,
        isOnSale: model.isOnSale
      )
    }
  }
}

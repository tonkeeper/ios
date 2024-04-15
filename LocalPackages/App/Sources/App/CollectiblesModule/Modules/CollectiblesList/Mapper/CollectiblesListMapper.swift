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
  
  func map(nfts: [NFT]) -> [CollectibleCollectionViewCell.Model] {
    nfts.map { nft in
      let title = nft.name ?? nft.address.toString(bounceable: true)
      let collectionName: String?
      if let collection = nft.collection {
        collectionName = (collection.name == nil || collection.name?.isEmpty == true) ? "Unnamed collection" : collection.name
      } else {
        collectionName = "Unnamed collection"
      }
      
      return CollectibleCollectionViewCell.Model(
        identifier: nft.address.toRaw(),
        imageDownloadTask: ImageDownloadTask(closure: { [weak imageLoader] imageView, size, cornerRadius in
          imageLoader?.loadImage(url: nft.preview.size500, imageView: imageView, size: size, cornerRadius: cornerRadius)
        }),
        title: title,
        subtitle: collectionName,
        isOnSale: nft.sale != nil
      )
    }
  }
}

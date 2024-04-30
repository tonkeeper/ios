import Foundation
import TonSwift

public struct NFTModel {
  public let address: Address
  public let name: String?
  public let collectionName: String?
  public let imageUrl: URL?
  public let isOnSale: Bool
}

public extension NFTModel {
  init(nft: NFT) {
    let name = nft.name ?? nft.address.toString(bounceable: true)
    let collectionName: String?
    if let collection = nft.collection {
      collectionName = (collection.name == nil || collection.name?.isEmpty == true) ? "Unnamed collection" : collection.name
    } else {
      collectionName = "Unnamed collection"
    }
    
    self.address = nft.address
    self.name = name
    self.collectionName = collectionName
    self.imageUrl = nft.preview.size500
    self.isOnSale = nft.sale != nil
  }
}

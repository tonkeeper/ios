import Foundation
import TonAPI
import TonSwift

extension NFT {
  private enum PreviewSize: String {
    case size5 = "5x5"
    case size100 = "100x100"
    case size500 = "500x500"
    case size1500 = "1500x1500"
  }
  
  init(nftItem: TonAPI.NftItem) throws {
    let address = try Address.parse(nftItem.address)
    var owner: WalletAccount?
    var name: String?
    var imageURL: URL?
    var description: String?
    var collection: NFTCollection?
    var isHidden = false
    
    if let ownerAccountAddress = nftItem.owner,
       let ownerWalletAccount = try? WalletAccount(accountAddress: ownerAccountAddress) {
      owner = ownerWalletAccount
    }
    
    name = nftItem.metadata["name"]?.value as? String
    imageURL = (nftItem.metadata["image"]?.value as? String).flatMap { URL(string: $0) }
    description = nftItem.metadata["description"]?.value as? String
    isHidden = (nftItem.metadata["render_type"]?.value as? String) == "hidden"
    
    var attributes = [Attribute]()
    if let attributesValue = nftItem.metadata["attributes"]?.value as? [AnyObject] {
      attributes = attributesValue
        .compactMap { $0 as? [String: AnyObject] }
        .compactMap { attributeObject -> Attribute? in
          guard let key = attributeObject["trait_type"] as? String else { return nil }
          let attributeValue: String
          switch attributeObject["value"] {
          case .none: return nil
          case .some(let value):
            switch value {
            case let stringValue as String:
              attributeValue = stringValue
            case let intValue as Int:
              attributeValue = String(intValue)
            case let doubleValue as Int:
              attributeValue = String(doubleValue)
            default:
              attributeValue = "-"
            }
          }
          return Attribute(key: key, value: attributeValue)
        }
    }
    
    if let nftCollection = nftItem.collection,
       let address = try? Address.parse(nftCollection.address) {
      collection = NFTCollection(address: address, name: nftCollection.name, description: nftCollection.description)
    }
    
    if imageURL == nil,
       let previewURLString = nftItem.previews?[2].url,
       let previewURL = URL(string: previewURLString) {
      imageURL = previewURL
    }
    
    var sale: Sale?
    if let nftSale = nftItem.sale {
      let address = try Address.parse(nftSale.address)
      let market = try WalletAccount(accountAddress: nftSale.market)
      var ownerWalletAccount: WalletAccount?
      if let nftSaleOwner = nftItem.owner {
        ownerWalletAccount = try WalletAccount(accountAddress: nftSaleOwner)
      }
      sale = Sale(address: address, market: market, owner: ownerWalletAccount)
    }
    
    let trust: Trust = {
      switch nftItem.trust {
      case ._none: return .none
      case .blacklist: return .blacklist
      case .graylist: return .graylist
      case .whitelist: return .whitelist
      case .unknownDefaultOpenApi: return .unknown
      }
    }()
    
    self.address = address
    self.owner = owner
    self.name = name
    self.imageURL = imageURL
    self.description = description
    self.attributes = attributes
    self.preview = Self.mapPreviews(nftItem.previews)
    self.collection = collection
    self.dns = nftItem.dns
    self.sale = sale
    self.isHidden = isHidden
    self.trust = trust
  }
  
  static private func mapPreviews(_ previews: [TonAPI.ImagePreview]?) -> Preview {
    var size5: URL?
    var size100: URL?
    var size500: URL?
    var size1500: URL?
    
    previews?.forEach { preview in
      guard let previewSize = PreviewSize(rawValue: preview.resolution) else { return }
      switch previewSize {
      case .size5:
        size5 = URL(string: preview.url)
      case .size100:
        size100 = URL(string: preview.url)
      case .size500:
        size500 = URL(string: preview.url)
      case .size1500:
        size1500 = URL(string: preview.url)
      }
    }
    return Preview(size5: size5, size100: size100, size500: size500, size1500: size1500)
  }
}

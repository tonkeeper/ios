import Foundation
import TonSwift

struct CollectibleDetailsMapper {
  
  private let dateFormatter: DateFormatter
  
  init(dateFormatter: DateFormatter) {
    self.dateFormatter = dateFormatter
    dateFormatter.dateFormat = "dd MMM yyyy"
  }
  
  func map(nft: NFT,
           isOwner: Bool,
           isActionsAvailable: Bool,
           linkedAddress: FriendlyAddress?,
           expirationDate: Date?,
           isInitial: Bool) -> CollectibleDetailsModel {
    
    let linkedAddressItem: LoadableModelItem<String?>? = {
      guard nft.dns != nil else { return nil }
      if let linkedAddress = linkedAddress {
        return .value(linkedAddress.toShort())
      } else if isInitial {
        return .loading
      } else {
        return .value(nil)
      }
    }()
    
    let expirationDateItem: LoadableModelItem<String>?
    let daysExpiration: Int?
    if let expirationDate = expirationDate {
      let formattedDate = dateFormatter.string(from: expirationDate)
      expirationDateItem = .value(formattedDate)
      daysExpiration = calculateDaysNumberToExpire(expirationDate: expirationDate)
    } else {
      expirationDateItem = nil
      daysExpiration = nil
    }
    
    let renewButtonDateItem: String?
    if let renewButtonDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) {
      renewButtonDateItem = dateFormatter.string(from: renewButtonDate)
    } else {
      renewButtonDateItem = nil
    }
    
    return CollectibleDetailsModel(
      title: nft.name ?? nft.address.toShortString(bounceable: false),
      collectibleDetails: mapCollectibleDetails(nft: nft),
      collectionDetails: mapCollectionDetails(nft: nft),
      properties: mapProperties(nft: nft),
      details: mapDetails(nft: nft),
      isTransferEnable: mapIsTransferEnable(nft: nft, isOwner: isOwner),
      isActionsAvailable: isOwner && isActionsAvailable,
      isDns: nft.dns != nil,
      isOnSale: nft.sale != nil,
      linkedAddress: linkedAddressItem,
      renewButtonDateItem: renewButtonDateItem,
      expirationDateItem: expirationDateItem,
      daysExpiration: daysExpiration)
  }
  
  private func mapCollectibleDetails(nft: NFT) -> CollectibleDetailsModel.CollectibleDetails {
    var subtitle: String?
    if nft.dns != nil {
      subtitle = "TON DNS"
    } else if let nft = nft.collection, let collectionName = nft.name {
      subtitle = collectionName
    } else {
      subtitle = "Single NFT"
    }
    
    let imageURL = nft.preview.size1500 ?? nft.preview.size500 ?? nft.imageURL
    
    return CollectibleDetailsModel.CollectibleDetails(
      imageURL: imageURL,
      title: nft.name,
      subtitle: subtitle,
      description: nft.description
    )
  }
  
  private func mapCollectionDetails(nft: NFT) -> CollectibleDetailsModel.CollectionDetails? {
    guard let collection = nft.collection else { return nil }
    var title: String?
    if let collectionName = collection.name {
      title = "About \(collectionName)"
    }
    
    return CollectibleDetailsModel.CollectionDetails(
      title: title,
      description: collection.description
    )
  }
  
  private func mapProperties(nft: NFT) -> [CollectibleDetailsModel.Property] {
    nft.attributes.map { CollectibleDetailsModel.Property(title: $0.key, value: $0.value) }
  }
  
  private func mapDetails(nft: NFT) -> CollectibleDetailsModel.Details {
    var items = [CollectibleDetailsModel.Details.Item]()
    if let owner = nft.owner {
      items.append(.init(
        title: "Owner",
        value: .init(
          short: owner.address.toShortString(bounceable: true),
          full: owner.address.toString(bounceable: true)
        )
      ))
    }
    items.append(.init(
      title: "Contract address",
      value: .init(
        short: nft.address.toShortString(bounceable: true),
        full: nft.address.toString(bounceable: true)
      )
    ))
    
    let url = URL.tonviewerURL.appendingPathComponent(nft.address.toRaw())
    return CollectibleDetailsModel.Details(items: items, url: url)
  }
  
  private func mapIsTransferEnable(
    nft: NFT,
    isOwner: Bool) -> Bool {
      return nft.sale == nil && isOwner
    }
  
  private func calculateDaysNumberToExpire(expirationDate: Date) -> Int {
    let calendar = Calendar.current
    let numberOfDays = calendar.dateComponents([.day], from: Date(), to: expirationDate)
    return (numberOfDays.day ?? 0)
  }
}

private extension URL {
  static let tonviewerURL = URL(string: "https://tonviewer.com/")!
}

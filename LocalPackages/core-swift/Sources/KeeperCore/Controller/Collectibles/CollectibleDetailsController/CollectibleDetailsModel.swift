import Foundation

public struct CollectibleDetailsModel {
  public struct CollectibleDetails {
    public let imageURL: URL?
    public let title: String?
    public let subtitle: String?
    public let description: String?
  }
  
  public struct CollectionDetails {
    public let title: String?
    public let description: String?
  }
  
  public struct Property {
    public let title: String
    public let value: String
  }
  
  public struct DetailsValue {
    public let short: String
    public let full: String?
  }
  
  public struct Details {
    public struct Item {
      public let title: String
      public let value: DetailsValue
    }
    
    public let items: [Item]
    public let url: URL?
  }
  
  public let title: String?
  public let collectibleDetails: CollectibleDetails
  public let collectionDetails: CollectionDetails?
  public let properties: [Property]
  public let details: Details
  public let isTransferEnable: Bool
  public let isDns: Bool
  public let isOnSale: Bool
  public let linkedAddress: LoadableModelItem<String?>?
  public let renewButtonDateItem: String?
  public let expirationDateItem: LoadableModelItem<String>?
  public let daysExpiration: Int?
}

import Foundation
import TonSwift

public struct NFT: Codable {
  public let address: Address
  public let owner: WalletAccount?
  public let name: String?
  public let imageURL: URL?
  public let preview: Preview
  public let description: String?
  public let attributes: [Attribute]
  public let collection: NFTCollection?
  public let dns: String?
  public let sale: Sale?
  public let isHidden: Bool
  
  public struct Marketplace {
    public let name: String
    public let url: URL?
  }
  
  public struct Attribute: Codable {
    public let key: String
    public let value: String
  }
  
  public enum Trust {
    public struct Approval {
      let name: String
    }
    case approvedBy([Approval])
  }
  
  public struct Preview: Codable {
    public let size5: URL?
    public let size100: URL?
    public let size500: URL?
    public let size1500: URL?
  }
  
  public struct Sale: Codable {
    public let address: Address
    public let market: WalletAccount
    public let owner: WalletAccount?
  }
}

public struct NFTCollection: Codable {
  public let address: Address
  public let name: String?
  public let description: String?
}

import Foundation
import TonSwift

public struct NFT: Codable, Equatable {
  public let address: Address
  public let owner: WalletAccount?
  public let name: String?
  public let imageURL: URL?
  public let preview: Preview
  public let description: String?
  public let attributes: [Attribute]
  public let collection: NFTCollection?
  public let programmaticButtons: [Button]?
  public let dns: String?
  public let sale: Sale?
  public let isHidden: Bool
  public let trust: Trust
  
  public var isUnverified: Bool {
    switch trust {
    case .whitelist, .graylist:
      return false
    case .blacklist, .none, .unknown:
      return true
    }
  }
  
  public var notNilName: String {
    if let name, !name.isEmpty {
      return name
    } else {
      return address.toShortString(bounceable: true)
    }
  }
  
  public struct Marketplace: Equatable {
    public let name: String
    public let url: URL?
  }
  
  public struct Attribute: Codable, Equatable {
    public let key: String
    public let value: String
  }
  
  public enum Trust: String, Equatable, Codable {
    case none
    case whitelist
    case blacklist
    case graylist
    case unknown
  }
  
  public struct Preview: Codable, Equatable {
    public let size5: URL?
    public let size100: URL?
    public let size500: URL?
    public let size1500: URL?
  }
  
  public struct Sale: Codable, Equatable {
    public let address: Address
    public let market: WalletAccount
    public let owner: WalletAccount?
  }

  public struct Button: Codable, Equatable {
    public let label: String?
    public let style: String?
    public let url: URL?

    public init(
      label: String?,
      style: String?,
      url: URL?
    ) {
      self.label = label
      self.style = style
      self.url = url
    }
  }
}

public struct NFTCollection: Codable, Equatable, Hashable {
  public let address: Address
  public let name: String?
  public let description: String?
  
  public var notEmptyName: String? {
    name?.isEmpty == false ? name : nil
  }
}

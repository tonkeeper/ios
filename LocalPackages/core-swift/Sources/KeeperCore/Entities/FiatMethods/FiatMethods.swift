import Foundation

public struct FiatMethodItem: Codable, Equatable, Hashable {
  public typealias ID = String
  
  public struct Button: Codable, Equatable, Hashable {
    public let title: String
    public let url: String
  }
  
  public enum CodingKeys: String, CodingKey {
    case id
    case title
    case isDisabled = "disabled"
    case badge
    case subtitle
    case description
    case iconURL = "icon_url"
    case actionButton = "action_button"
    case infoButtons = "info_buttons"
  }
  
  public let id: ID
  public let title: String
  public let subtitle: String?
  public let isDisabled: Bool
  public let badge: String?
  public let description: String?
  public let iconURL: URL?
  public let actionButton: Button
  public let infoButtons: [Button]
}

public struct FiatMethodCategory: Codable, Equatable, Hashable {
  public enum Asset: String, Codable {
    case USDT
    case BTC
    case ETH
    case SOL
    case TON
    case BNB
    case XRP
    case ADA
    case NOT
  }
  
  public let title: String?
  public let subtitle: String?
  public let items: [FiatMethodItem]
  public let assets: [Asset]
  
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    title = try container.decodeIfPresent(String.self, forKey: .title)
    subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
    items = try container.decode([FiatMethodItem].self, forKey: .items)
    
    var array = try container.nestedUnkeyedContainer(forKey: .assets)
    var assets = [Asset]()
    while !array.isAtEnd {
      let assetRaw = try array.decode(String.self)
      if let asset = Asset(rawValue: assetRaw) {
        assets.append(asset)
      }
    }
    self.assets = assets
  }
}

public struct FiatMethodDefaultLayout: Codable, Equatable {
  public let methods: [FiatMethodItem.ID]
}

public struct FiatMethodLayoutByCountry: Codable, Equatable {
  public let countryCode: String
  public let currency: String
  public let methods: [FiatMethodItem.ID]
}

public struct FiatMethods: Codable, Equatable {
  public let layoutByCountry: [FiatMethodLayoutByCountry]
  public let defaultLayout: FiatMethodDefaultLayout
  public let categories: [FiatMethodCategory]
  public let buy: [FiatMethodCategory]
  public let sell: [FiatMethodCategory]
}

public struct FiatMethodsResponse: Codable {
  public let data: FiatMethods
}

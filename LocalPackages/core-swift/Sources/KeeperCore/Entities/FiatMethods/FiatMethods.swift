import Foundation
import TonSwift

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

public extension FiatMethodItem {
  func actionURL(walletAddress: FriendlyAddress, currency: Currency, mercuryoSecret: String?) -> URL? {
    let isSell = id.contains("sell")
    
    var urlString = actionButton.url
    
    switch id {
    case _ where id.contains("mercuryo"):
      urlForMercuryo(
        urlString: &urlString,
        isSell: isSell,
        walletAddress: walletAddress,
        mercuryoSecret: mercuryoSecret
      )
    default:
      break
    }
    if isSell {
      urlString = urlString.replacingOccurrences(of: "{CUR_FROM}", with: "TONCOIN")
      urlString = urlString.replacingOccurrences(of: "{CUR_TO}", with: currency.code)
    } else {
      urlString = urlString.replacingOccurrences(of: "{CUR_FROM}", with: currency.code)
      urlString = urlString.replacingOccurrences(of: "{CUR_TO}", with: "TON")
    }
  
    urlString = urlString.replacingOccurrences(of: "{ADDRESS}", with: walletAddress.toString())
    guard let url = URL(string: urlString) else { return nil }
    return url
  }
  
  private func urlForMercuryo(urlString: inout String,
                              isSell: Bool,
                              walletAddress: FriendlyAddress,
                              mercuryoSecret: String?) {
    if isSell {
      urlString = urlString.replacingOccurrences(of: "{CUR_TO}", with: "TONCOIN")
    } else {
      urlString = urlString.replacingOccurrences(of: "{CUR_FROM}", with: "TONCOIN")
    }
 
    urlString = urlString.replacingOccurrences(of: "{TX_ID}", with: "mercuryo_\(UUID().uuidString)")
    
    let mercuryoSecret = mercuryoSecret ?? ""

    guard let signature = (walletAddress.toString() + mercuryoSecret).data(using: .utf8)?.sha256().hexString() else { return }
    urlString += "&signature=\(signature)"
  }
}


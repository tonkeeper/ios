import Foundation

struct StonfiAssets: Codable {
  let expirationDate: Date
  let items: [StonfiAsset]
  
  var isValid: Bool {
    !items.isEmpty && expirationDate.timeIntervalSinceNow > 0
  }
}

extension StonfiAssets {
  init() {
    self.init(
      expirationDate: Date(timeIntervalSince1970: 0),
      items: []
    )
  }
}

public struct StonfiAsset: Codable {
  public let contractAddress: String
  public let symbol: String
  public let displayName: String?
  public let imageUrl: String?
  public let decimals: Int
  public let kind: String
  public let isDeprecated: Bool
  public let isCommunity: Bool
  public let isBlacklisted: Bool
  public let dexPriceUsd: String?
  
  enum CodingKeys: String, CodingKey {
    case contractAddress = "contract_address"
    case symbol
    case displayName = "display_name"
    case imageUrl = "image_url"
    case decimals
    case kind
    case isDeprecated = "deprecated"
    case isCommunity = "community"
    case isBlacklisted = "blacklisted"
  }
}

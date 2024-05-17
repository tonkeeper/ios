import Foundation

struct StonfiAssets: Codable {
  let expirationDate: Date
  let items: [StonfiAsset]
}

public struct StonfiAsset: Codable {
  public let contractAddress: String
  public let symbol: String
  public let displayName: String?
  public let imageUrl: String?
  public let decimals: Int
  public let kind: String
  
  enum CodingKeys: String, CodingKey {
    case contractAddress = "contract_address"
    case symbol
    case displayName = "display_name"
    case imageUrl = "image_url"
    case decimals
    case kind
  }
}

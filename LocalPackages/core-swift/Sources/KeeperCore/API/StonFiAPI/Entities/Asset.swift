import Foundation

public struct Asset: Codable, Equatable, Hashable {
  public let contractAddress: String?             // for simplicity, nil considered as toncoin!
  public let symbol: String
  public let displayName: String
  public let imageUrl: String
  public let decimals: Int
  public let kind: String
  public let deprecated: Bool?
  public let community: Bool?
  public let blacklisted: Bool?
  public let defaultSymbol: Bool?
  public let thirdPartyUsdPrice: String?
  public let thirdPartyPriceUsd: String?
  public let dexUsdPrice: String?
  public let dexPriceUsd: String?
  
  public var isSwappable: Bool = false

  enum CodingKeys: String, CodingKey {
      case contractAddress = "contract_address"
      case symbol
      case displayName = "display_name"
      case imageUrl = "image_url"
      case decimals
      case kind
      case deprecated
      case community
      case blacklisted
      case defaultSymbol = "default_symbol"
      case thirdPartyUsdPrice = "third_party_usd_price"
      case thirdPartyPriceUsd = "third_party_price_usd"
      case dexUsdPrice = "dex_usd_price"
      case dexPriceUsd = "dex_price_usd"
  }
  
  public init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      contractAddress = try container.decodeIfPresent(String.self, forKey: .contractAddress)
      symbol = try container.decode(String.self, forKey: .symbol)
      displayName = try container.decode(String.self, forKey: .displayName)
      imageUrl = try container.decode(String.self, forKey: .imageUrl)
      decimals = try container.decode(Int.self, forKey: .decimals)
      kind = try container.decode(String.self, forKey: .kind)
      deprecated = try container.decodeIfPresent(Bool.self, forKey: .deprecated)
      community = try container.decodeIfPresent(Bool.self, forKey: .community)
      blacklisted = try container.decodeIfPresent(Bool.self, forKey: .blacklisted)
      defaultSymbol = try container.decodeIfPresent(Bool.self, forKey: .defaultSymbol)
      thirdPartyUsdPrice = try container.decodeIfPresent(String.self, forKey: .thirdPartyUsdPrice)
      thirdPartyPriceUsd = try container.decodeIfPresent(String.self, forKey: .thirdPartyPriceUsd)
      dexUsdPrice = try container.decodeIfPresent(String.self, forKey: .dexUsdPrice)
      dexPriceUsd = try container.decodeIfPresent(String.self, forKey: .dexPriceUsd)
  }
  
  public init(jettonInfo: JettonInfo) {
    self.contractAddress = jettonInfo.address.toString()
    self.symbol = jettonInfo.symbol ?? ""
    self.displayName = jettonInfo.name
    self.imageUrl = jettonInfo.imageURL?.absoluteString ?? ""
    self.decimals = jettonInfo.fractionDigits
    self.kind = "jetton"
    self.deprecated = nil
    self.community = nil
    self.blacklisted = (jettonInfo.verification == .blacklist)
    self.defaultSymbol = (jettonInfo.verification == .whitelist)
    self.thirdPartyUsdPrice = nil
    self.thirdPartyPriceUsd = nil
    self.dexUsdPrice = nil
    self.dexPriceUsd = nil
  }

  private init(contractAddress: String?, symbol: String, displayName: String, imageUrl: String, decimals: Int, kind: String, deprecated: Bool?, community: Bool?, blacklisted: Bool?, defaultSymbol: Bool?, thirdPartyUsdPrice: String?, thirdPartyPriceUsd: String?, dexUsdPrice: String?, dexPriceUsd: String?, isSwappable: Bool) {
    self.contractAddress = contractAddress
    self.symbol = symbol
    self.displayName = displayName
    self.imageUrl = imageUrl
    self.decimals = decimals
    self.kind = kind
    self.deprecated = deprecated
    self.community = community
    self.blacklisted = blacklisted
    self.defaultSymbol = defaultSymbol
    self.thirdPartyUsdPrice = thirdPartyUsdPrice
    self.thirdPartyPriceUsd = thirdPartyPriceUsd
    self.dexUsdPrice = dexUsdPrice
    self.dexPriceUsd = dexPriceUsd
    self.isSwappable = isSwappable
  }
  
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.contractAddress == rhs.contractAddress
  }
  
  public func hash(into hasher: inout Hasher) {
    hasher.combine(contractAddress)
  }

  public static var toncoin = Asset(contractAddress: "EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c",
                                    symbol: "TON",
                                    displayName: "Toncoin",
                                    imageUrl: "",
                                    decimals: 9,
                                    kind: "ton",
                                    deprecated: nil, community: nil, blacklisted: nil, defaultSymbol: nil, thirdPartyUsdPrice: nil, thirdPartyPriceUsd: nil, dexUsdPrice: nil, dexPriceUsd: nil,
                                    isSwappable: true)
}

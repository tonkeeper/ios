import Foundation
import BigInt

public struct Operator: Codable {
  public let id: String
  public let name: String
  public let currency: Currency
  public let rate: Decimal
  public let logo: URL?
  public let minTonBuyAmount: BigUInt?
  public let minTonSellAmount: BigUInt?
  
  enum CodingKeys: String, CodingKey {
    case id
    case name
    case currency
    case rate
    case logo
    case minTonBuyAmount = "min_ton_buy_amount"
    case minTonSellAmount = "min_ton_sell_amount"
  }
  
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(String.self, forKey: .id)
    self.name = try container.decode(String.self, forKey: .name)
    self.currency = try container.decode(Currency.self, forKey: .currency)
    self.rate = try container.decode(Decimal.self, forKey: .rate)
    self.logo = try container.decodeIfPresent(URL.self, forKey: .logo) ?? nil
    
    let minTonBuyAmount = try container.decodeIfPresent(Int64.self, forKey: .minTonBuyAmount) ?? nil
    if let minTonBuyAmount {
      self.minTonBuyAmount = BigUInt(integerLiteral: UInt64(minTonBuyAmount))
    } else {
      self.minTonBuyAmount = nil
    }
    
    let minTonSellAmount = try container.decodeIfPresent(Int64.self, forKey: .minTonSellAmount) ?? nil
    if let minTonSellAmount {
      self.minTonSellAmount = BigUInt(integerLiteral: UInt64(minTonSellAmount))
    } else {
      self.minTonSellAmount = nil
    }
  }
  
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(self.id, forKey: .id)
    try container.encode(self.name, forKey: .name)
    try container.encode(self.currency, forKey: .currency)
    try container.encode(self.rate, forKey: .rate)
    try container.encode(self.logo, forKey: .logo)
    try container.encode(self.minTonBuyAmount, forKey: .minTonBuyAmount)
    try container.encode(self.minTonSellAmount, forKey: .minTonSellAmount)
  }
}

struct OperatorsResponse: Codable {
  let items: [Operator]
}

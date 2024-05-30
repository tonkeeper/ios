import Foundation

struct FiatMethodRate: Decodable {
  let id: String
  let name: String
  let rate: Decimal
  let currency: String
  let minTonBuyAmount: UInt64?
  let minTonSellAmount: UInt64?
  
  enum CodingKeys: String, CodingKey {
    case id
    case name
    case rate
    case currency
    case minTonBuyAmount = "min_ton_buy_amount"
    case minTonSellAmount = "min_ton_sell_amount"
  }
}

struct FiatMethodsRatesResponse: Decodable {
  let items: [FiatMethodRate]
}

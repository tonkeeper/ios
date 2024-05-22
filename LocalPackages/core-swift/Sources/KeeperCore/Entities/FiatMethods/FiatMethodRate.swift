import Foundation

struct FiatMethodRate: Decodable {
  let id: String
  let name: String
  let rate: Decimal
  let currency: String
}

struct FiatMethodsRatesResponse: Decodable {
  let items: [FiatMethodRate]
}

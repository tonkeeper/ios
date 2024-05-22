import Foundation

public struct Operator: Codable {
  public let id: String
  public let name: String
  public let currency: Currency
  public let rate: Decimal
  public let logo: URL?
}

struct OperatorsResponse: Codable {
  let items: [Operator]
}

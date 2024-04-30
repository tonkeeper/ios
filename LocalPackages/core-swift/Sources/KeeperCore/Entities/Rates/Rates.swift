import Foundation

public struct Rates: Codable {
  public struct Rate: Codable {
    public let currency: Currency
    public let rate: Decimal
    public let diff24h: String?
  }
  
  public struct JettonRate: Codable {
    public let jettonInfo: JettonInfo
    public var rates: [Rate]
  }
  
  public var ton: [Rate]
  public var jettonsRates: [JettonRate]
}


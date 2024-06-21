import Foundation

public struct Rates: Codable, Equatable {
  public struct Rate: Codable, Equatable {
    public let currency: Currency
    public let rate: Decimal
    public let diff24h: String?
  }
  
  public struct JettonRate: Codable, Equatable {
    public let jettonInfo: JettonInfo
    public var rates: [Rate]
  }
  
  public var ton: [Rate]
  public var jettonsRates: [JettonRate]
}


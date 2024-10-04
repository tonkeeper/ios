import Foundation

public struct Rates: Codable, Equatable {
  public struct Rate: Codable, Equatable {
    public let currency: Currency
    public let rate: Decimal
    public let diff24h: String?
    
    public init(currency: Currency, rate: Decimal, diff24h: String?) {
      self.currency = currency
      self.rate = rate
      self.diff24h = diff24h
    }
  }
  
  public struct JettonRate: Codable, Equatable {
    public let jettonInfo: JettonInfo
    public var rates: [Rate]
  }
  
  public var ton: [Rate]
  public var jettonsRates: [JettonRate]
}


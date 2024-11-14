import Foundation
import TonSwift

public struct BatteryRechargeMethod: Codable {
  public enum Token: Equatable, Codable {
    case ton
    case jetton(Jetton)
    
    public static func ==(lhs: Token, rhs: Token) -> Bool {
      switch (lhs, rhs) {
      case (.ton, .ton):
        return true
      case (.jetton(let lJetton), .jetton(let rJetton)):
        return lJetton.jettonMasterAddress == rJetton.jettonMasterAddress
      default:
        return false
      }
    }
    
    public var jettonMasterAddress: Address? {
      switch self {
      case .ton:
        return nil
      case .jetton(let jetton):
        return jetton.jettonMasterAddress
      }
    }
  }
  
  public struct Jetton: Codable {
    public let jettonMasterAddress: Address
  }
  
  public let token: Token
  public let imageURL: URL?
  public let minBootstrapValue: NSDecimalNumber?
  public let rate: NSDecimalNumber
  public let symbol: String
  public let decimals: Int
  public let supportGasless: Bool
  public let supportRecharge: Bool
  
  public var jettonMasterAddress: Address? {
    switch token {
    case .ton:
      nil
    case .jetton(let jetton):
      jetton.jettonMasterAddress
    }
  }
  
  enum CodingKeys: String, CodingKey {
    case token
    case imageURL
    case minBootstrapValue
    case rate
    case symbol
    case decimals
    case supportGasless
    case supportRecharge
  }
  
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    token = try container.decode(Token.self, forKey: .token)
    imageURL = try container.decodeIfPresent(URL.self, forKey: .imageURL)
    symbol = try container.decode(String.self, forKey: .symbol)
    decimals = try container.decode(Int.self, forKey: .decimals)
    supportGasless = try container.decode(Bool.self, forKey: .supportGasless)
    supportRecharge = try container.decode(Bool.self, forKey: .supportRecharge)
    
    if let minBootstrapValueString = try container.decodeIfPresent(String.self, forKey: .minBootstrapValue) {
      minBootstrapValue = NSDecimalNumber(string: minBootstrapValueString)
    } else {
      minBootstrapValue = nil
    }
    let rateString = try container.decode(String.self, forKey: .rate)
    rate = NSDecimalNumber(string: rateString)
  }
  
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(token, forKey: .token)
    try container.encode(imageURL, forKey: .imageURL)
    try container.encode(symbol, forKey: .symbol)
    try container.encode(decimals, forKey: .decimals)
    try container.encode(supportGasless, forKey: .supportGasless)
    try container.encode(supportRecharge, forKey: .supportRecharge)
    try container.encodeIfPresent(minBootstrapValue?.stringValue, forKey: .minBootstrapValue)
    try container.encode(rate.stringValue, forKey: .rate)
  }
}

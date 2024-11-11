import Foundation
import TonSwift

public struct SendTransactionParam: Decodable {
  public let messages: [Message]
  public let validUntil: TimeInterval
  public let from: Address?
  
  enum CodingKeys: String, CodingKey {
    case messages
    case validUntil = "valid_until"
    case from
    case source
  }
  
  public init(messages: [Message], 
              validUntil: TimeInterval,
              from: Address?) {
    self.messages = messages
    self.validUntil = validUntil
    self.from = from
  }
  
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    messages = try container.decode([Message].self, forKey: .messages)
    validUntil = try container.decode(TimeInterval.self, forKey: .validUntil)
    
    if let fromValue = try? container.decode(String.self, forKey: .from) {
      from = try Address.parse(fromValue)
    } else {
      from = try Address.parse(try container.decode(String.self, forKey: .source))
    }
  }
  
  public struct Message: Decodable {
    public let address: AnyAddress
    public let amount: Int64
    public let stateInit: String?
    public let payload: String?
    
    enum CodingKeys: String, CodingKey {
      case address
      case amount
      case stateInit
      case payload
    }
    
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      address = try container.decode(AnyAddress.self, forKey: .address)
      if let amountString = try? container.decode(String.self, forKey: .amount) {
        amount = Int64(amountString) ?? 0
      } else {
        amount = try container.decode(Int64.self, forKey: .amount)
      }
    
      stateInit = try container.decodeIfPresent(String.self, forKey: .stateInit)
      payload = try container.decodeIfPresent(String.self, forKey: .payload)
    }
    
    public init(address: AnyAddress, amount: Int64, stateInit: String?, payload: String?) {
      self.address = address
      self.amount = amount
      self.stateInit = stateInit
      self.payload = payload
    }
  }
}

public struct SendTransactionSignRequest: Decodable {
  
  public let params: [SendTransactionParam]
  
  enum CodingKeys: String, CodingKey {
    case params
  }
  
  public init(from decoder: Decoder) throws {
    var container = try decoder.unkeyedContainer()
    var params = [SendTransactionParam]()
    while !container.isAtEnd {
      let param = try container.decode(SendTransactionParam.self)
      params.append(param)
    }
    self.params = params
  }
}

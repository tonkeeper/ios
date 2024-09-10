import Foundation
import TonSwift
import BigInt

public enum Deeplink {
  case tonkeeper(TonkeeperDeeplink)
  case ton(TonDeeplink)
  case tonConnect(TonConnectDeeplink)
  
  public var string: String {
    switch self {
    case .ton(let tonDeeplink):
      return tonDeeplink.string
    case .tonConnect(let tonConnectDeeplink):
      return tonConnectDeeplink.string
    default: return ""
    }
  }
}

public enum TonDeeplink {
  case transfer(recipient: String, amount: BigUInt?, comment: String?, jettonAddress: Address?)
  case buyTon
  case staking
  case pool(Address)
  case exchange(provider: String)
  case swap(fromToken: String?, toToken: String?)
  
  public var string: String {
    let ton = "ton"
    var components = URLComponents(string: ton)
    components?.scheme = ton
    switch self {
    case let .transfer(recipient, amount, comment, jettonAddress):
      components?.host = "transfer"
      components?.path = "/\(recipient)"
      if let amount {
        components?.queryItems = [URLQueryItem(name: "amount", value: amount.description)]
      }
      if let comment {
        components?.queryItems = [URLQueryItem(name: "text", value: comment)]
      }
      if let jettonAddress {
        components?.queryItems = [URLQueryItem(name: "jetton", value: jettonAddress.toRaw())]
      }
    case .buyTon:
      components?.host = "buy-ton"
    case .staking:
      components?.host = "staking"
    case .pool(let address):
      components?.host = "pool"
      components?.path = "/\(address.toRaw())"
    case .exchange(let provider):
      components?.host = "exchange"
      components?.path = "/\(provider)"
    case .swap(let fromToken, let toToken):
      components?.host = "swap"
      if let fromToken {
        components?.queryItems = [URLQueryItem(name: "ft", value: fromToken)]
      }
      if let toToken {
        components?.queryItems = [URLQueryItem(name: "tt", value: toToken)]
      }
    }
    return components?.string ?? ""
  }
}

public struct TonConnectDeeplink {
  let string: String
}

public struct TonkeeperPublishModel {
  public let sign: Data
}

public enum TonkeeperDeeplink {
  public enum SignerDeeplink {
    case link(publicKey: TonSwift.PublicKey, name: String)
    
    public var string: String { "" }
  }
  
  case signer(SignerDeeplink)
  case publish(TonkeeperPublishModel)
  
  public var string: String { "" }
}

public enum TonsignDeeplink {
  case plain
  
  public var string: String {
    let tonsign = "tonsign"
    switch self {
    case .plain:
      var components = URLComponents()
      components.scheme = tonsign
      return components.string ?? ""
    }
  }
}

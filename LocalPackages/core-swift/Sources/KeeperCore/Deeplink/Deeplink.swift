import Foundation
import TonSwift

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
  case transfer(recipient: String, jettonAddress: Address?)
  
  public var string: String {
    let ton = "ton"
    switch self {
    case let .transfer(recipient, jettonAddress):
      var components = URLComponents(string: ton)
      components?.scheme = ton
      components?.host = "transfer"
      components?.path = "/\(recipient)"
      if let jettonAddress {
        components?.queryItems = [URLQueryItem(name: "jetton", value: jettonAddress.toRaw())]
      }
      return components?.string ?? ""
    }
  }
}

public struct TonConnectDeeplink {
  let string: String
}

public enum TonkeeperDeeplink {
  public enum SignerDeeplink {
    case link(publicKey: TonSwift.PublicKey, name: String)
    
    public var string: String { "" }
  }
  
  case signer(SignerDeeplink)
  
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

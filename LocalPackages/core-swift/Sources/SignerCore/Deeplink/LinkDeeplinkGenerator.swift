import Foundation
import TonSwift

struct LinkDeeplinkGenerator {
  func generateAppDeeplink(network: Network, key: WalletKey) -> URL? {
    guard let publicKey = key
      .publicKey.data.base64EncodedString()
      .percentEncoded else {
      return nil
    }
    
    var components = URLComponents()
    components.scheme = "tonkeeper"
    components.host = "signer"
    components.path = "/link"
    components.percentEncodedQueryItems = [
      URLQueryItem(name: "pk", value: publicKey),
      URLQueryItem(name: "name", value: key.name),
      URLQueryItem(name: "network", value: network.rawValue)
    ]
    return components.url
  }
  
  func generateWebDeeplink(network: Network, key: WalletKey) -> URL? {
    guard let publicKey = key
      .publicKey.data.base64EncodedString()
      .percentEncoded else {
      return nil
    }
    
    var components = URLComponents()
    components.scheme = "https"
    components.host = "wallet.tonkeeper.com"
    components.path = "/signer/link"
    components.percentEncodedQueryItems = [
      URLQueryItem(name: "pk", value: publicKey),
      URLQueryItem(name: "name", value: key.name),
      URLQueryItem(name: "network", value: network.rawValue)
    ]
    return components.url
  }
}

enum Network: String {
  case ton
}

import Foundation
import TonSwift

struct LinkDeeplinkGenerator {
  func generateAppDeeplink(network: Network, key: WalletKey, local: Bool) -> URL? {
    let hexPublicKey = key.publicKey.data.hexString()

    var components = URLComponents()
    components.scheme = "tonkeeper"
    components.host = "signer"
    components.path = "/link"
    components.queryItems = [
      URLQueryItem(name: "pk", value: hexPublicKey),
      URLQueryItem(name: "name", value: key.name),
      URLQueryItem(name: "network", value: network.rawValue),
      URLQueryItem(name: "local", value: "\(local)")
    ]
    return components.url
  }
  
  func generateWebDeeplink(network: Network, key: WalletKey) -> URL? {
    let hexPublicKey = key.publicKey.data.hexString()
    
    var components = URLComponents()
    components.scheme = "https"
    components.host = "wallet.tonkeeper.com"
    components.path = "/signer/link"
    components.queryItems = [
      URLQueryItem(name: "pk", value: hexPublicKey),
      URLQueryItem(name: "name", value: key.name),
      URLQueryItem(name: "network", value: network.rawValue)
    ]
    return components.url
  }
}

enum Network: String {
  case ton
}

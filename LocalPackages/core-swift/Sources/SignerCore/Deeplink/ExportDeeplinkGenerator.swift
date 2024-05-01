import Foundation
import TonSwift

struct ExportDeeplinkGenerator {
  func generateDeeplink(network: Network, key: WalletKey) -> URL? {
    var components = URLComponents()
    components.scheme = "tonkeeper"
    components.host = "signer"
    components.path = "/link"
    components.queryItems = [
      URLQueryItem(name: "pk", value: key.publicKey.data.base64EncodedString()),
      URLQueryItem(name: "name", value: key.name),
      URLQueryItem(name: "network", value: network.rawValue)
    ]
    return components.url
  }
}

enum Network: String {
  case ton
}

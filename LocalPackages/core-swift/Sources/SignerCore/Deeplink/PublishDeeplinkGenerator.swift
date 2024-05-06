import Foundation

struct PublishDeeplinkGenerator {
  func generatePublishDeeplink(signature: Data, network: String?, version: String?) -> URL? {
    guard let signatureEncoded = signature
      .base64EncodedString()
      .percentEncoded else { return nil }
    
    let parameters = [
      DeeplinkParameter.boc.rawValue: signatureEncoded,
      DeeplinkParameter.network.rawValue: network,
      DeeplinkParameter.v.rawValue: version
    ]
    
    var components = URLComponents()
    components.scheme = DeeplinkScheme.tonkeeper.rawValue
    components.host = "publish"
    components.percentEncodedQueryItems = parameters.compactMap {
      guard let value = $0.value else { return nil }
      return URLQueryItem(name: $0.key, value: value)
    }
    return components.url
  }
}

import Foundation

struct PublishDeeplinkGenerator {
  func generatePublishDeeplink(signature: Data, network: String?, version: String?, return: String?) -> URL? {
    guard let signatureEncoded = signature
      .base64EncodedString()
      .percentEncoded else { return nil }
    
    var urlString: String
    if let `return` {
      urlString = `return`
    } else {
      urlString = "tonkeeperx://publish"
    }
    
    let parameters: [String] = [
      DeeplinkParameter.boc.rawValue: signatureEncoded,
      DeeplinkParameter.network.rawValue: network,
      DeeplinkParameter.v.rawValue: version
    ].compactMap {
      guard let value = $0.value else { return nil }
      return "\($0.key)=\(value)"
    }

    urlString = "\(urlString)?\(parameters.joined(separator: "&"))"
    return URL(string: urlString)
  }
}

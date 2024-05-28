import Foundation

struct PublishDeeplinkGenerator {
  func generatePublishDeeplink(signature: Data, return: String?) -> URL? {
    let hexSignature = signature.hexString()
    
    var urlString: String
    if let `return` {
      urlString = `return`
    } else {
      urlString = "tonkeeper://publish"
    }
    
    let parameters: [String] = [
      DeeplinkParameter.sign.rawValue: hexSignature,
    ].map {
      return "\($0.key)=\($0.value)"
    }

    urlString = "\(urlString)?\(parameters.joined(separator: "&"))"
    return URL(string: urlString)
  }
}

import Foundation

extension URL {
    var proxyURL: URL? {
        let urlString = absoluteString
        let base64EncodedUrlString = urlString.data(using: .utf8)?.base64EncodedString()
            .base64URLEncoded()
        var components = URLComponents(string: "https://c.tonapi.io")
        components?.path = "/json"
        components?.queryItems = [URLQueryItem(name: "url", value: base64EncodedUrlString)]
        return components?.url
    }
}

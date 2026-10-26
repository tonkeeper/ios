import Foundation

public extension URL {
    var proxyURL: URL? {
        proxyURL(noCache: false)
    }

    func proxyURL(noCache: Bool) -> URL? {
        let urlString = absoluteString
        // The proxy rejects unpadded base64, so only the alphabet is made URL-safe.
        let base64EncodedUrlString = urlString.data(using: .utf8)?.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
        var components = URLComponents(string: "https://c.tonapi.io")
        components?.path = "/json"
        var queryItems = [URLQueryItem(name: "url", value: base64EncodedUrlString)]
        if noCache {
            queryItems.append(URLQueryItem(name: "no-cache", value: "true"))
        }
        components?.queryItems = queryItems
        return components?.url
    }
}

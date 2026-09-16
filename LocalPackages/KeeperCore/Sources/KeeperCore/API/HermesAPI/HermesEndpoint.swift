import Foundation

enum HermesEndpoint {
    static func webSocketURL(from host: URL) -> URL? {
        var components = URLComponents(url: host, resolvingAgainstBaseURL: false)
        switch components?.scheme {
        case "http":
            components?.scheme = "ws"
        default:
            components?.scheme = "wss"
        }
        let basePath = (components?.path ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let suffix = "hermes/public-api/v1/ws"
        components?.path = basePath.isEmpty ? "/\(suffix)" : "/\(basePath)/\(suffix)"
        components?.query = nil
        components?.fragment = nil
        return components?.url
    }
}

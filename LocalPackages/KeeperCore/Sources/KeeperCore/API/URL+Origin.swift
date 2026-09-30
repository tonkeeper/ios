import Foundation

struct NormalizedURLOrigin: Equatable, Sendable {
    let scheme: String
    let host: String
    let port: Int
}

extension URL {
    var normalizedOrigin: NormalizedURLOrigin? {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
              let rawScheme = components.scheme,
              let rawHost = components.host
        else {
            return nil
        }

        let scheme = rawScheme.lowercased()
        let host = rawHost.lowercased()
        guard !host.isEmpty else {
            return nil
        }

        let defaultPort: Int
        switch scheme {
        case "http":
            defaultPort = 80
        case "https":
            defaultPort = 443
        default:
            return nil
        }

        return NormalizedURLOrigin(
            scheme: scheme,
            host: host,
            port: components.port ?? defaultPort
        )
    }
}

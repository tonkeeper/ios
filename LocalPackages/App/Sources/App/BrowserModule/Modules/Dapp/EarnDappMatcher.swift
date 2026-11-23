import Foundation

/// Only the site of the Earn page keys/all names (`earnUrl`), subdomains included, gets the native bridge
/// and the wallet's EVM provider.
struct EarnDappMatcher {
    private let earnURL: URL

    init(earnURL: URL) {
        self.earnURL = earnURL
    }

    func matches(url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https",
              earnURL.scheme?.lowercased() == "https",
              let host = url.host?.lowercased(),
              let earnHost = earnURL.host?.lowercased(),
              !earnHost.isEmpty,
              (url.port ?? 443) == (earnURL.port ?? 443)
        else {
            return false
        }
        return host == earnHost || host.hasSuffix(".\(earnHost)")
    }
}

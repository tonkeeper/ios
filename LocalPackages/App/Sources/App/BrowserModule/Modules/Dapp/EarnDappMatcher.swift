import Foundation

struct EarnDappMatcher {
    static let earnHostSuffixes: Set<String> = [
        "vaults.fyi",
        "vaults-tonkeeper-earn-latest-demo.fly.dev",
    ]

    private let hostSuffixes: Set<String>

    init(hostSuffixes: Set<String> = EarnDappMatcher.earnHostSuffixes) {
        self.hostSuffixes = hostSuffixes
    }

    func matches(url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https", let host = url.host?.lowercased() else {
            return false
        }
        return hostSuffixes.contains { host == $0 || host.hasSuffix(".\($0)") }
    }
}

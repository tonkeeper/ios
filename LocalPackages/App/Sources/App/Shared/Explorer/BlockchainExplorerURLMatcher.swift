import Foundation
import KeeperCore

struct BlockchainExplorerURLMatcher {
    private let templatesProvider: () -> [String]

    init(templatesProvider: @escaping () -> [String]) {
        self.templatesProvider = templatesProvider
    }

    init(configuration: Configuration) {
        self.init(templatesProvider: {
            [Network.mainnet, .testnet].flatMap { network in
                configuration.explorers(network: network).flatMap { [$0.url, $0.tokenURL] } + [
                    configuration.accountExplorer(network: network),
                    configuration.transactionExplorer(network: network),
                    configuration.nftOnExplorer(network: network),
                ]
            }
            .compactMap { $0 }
        })
    }

    func matches(url: URL) -> Bool {
        guard let host = url.host?.lowercased() else {
            return false
        }
        return hosts().contains(host)
    }

    private func hosts() -> Set<String> {
        Set(templatesProvider().compactMap(Self.host(inTemplate:)))
    }

    /// An explorer is configured as a template, and neither `{tx_hash}` nor `%s` is a valid URL
    /// character, so only the authority of such a string can be parsed.
    private static func host(inTemplate template: String) -> String? {
        guard let schemeSeparator = template.range(of: "://") else {
            return nil
        }
        let authority = template[schemeSeparator.upperBound...].prefix { !"/?#".contains($0) }
        return URLComponents(
            string: String(template[..<schemeSeparator.upperBound] + authority)
        )?.host?.lowercased()
    }
}

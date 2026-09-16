import KeeperCore

extension MultichainSwapQuote {
    var offeredRoutesLogDescription: String {
        routes.map(\.providerLogDescription).joined(separator: ",")
    }
}

private extension MultichainSwapRoute {
    var providerLogDescription: String {
        protocolSlug.map { "\(aggregator)/\($0)" } ?? aggregator
    }
}

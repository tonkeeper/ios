struct KandelabrAPIHostProvider: APIHostProvider {
    private let configuration: Configuration

    init(configuration: Configuration) {
        self.configuration = configuration
    }

    var basePath: String {
        get async {
            let network: Network = configuration.lighterAPIEnvironment == .testnet ? .testnet : .mainnet
            return await configuration.multichainHost(network: network).absoluteString
        }
    }
}

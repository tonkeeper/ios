struct KandelabrAPIHostProvider: APIHostProvider {
    private let configuration: Configuration

    init(configuration: Configuration) {
        self.configuration = configuration
    }

    var basePath: String {
        get async {
            await configuration.multichainHost(network: .mainnet).absoluteString
        }
    }
}

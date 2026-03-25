struct MainnetBatteryAPIHostProvider: APIHostProvider {
    private let configuration: Configuration

    init(configuration: Configuration) {
        self.configuration = configuration
    }

    var basePath: String {
        get async {
            await configuration.batteryHost(network: .mainnet)
        }
    }
}

struct TestnetBatteryAPIHostProvider: APIHostProvider {
    private let configuration: Configuration

    init(configuration: Configuration) {
        self.configuration = configuration
    }

    var basePath: String {
        get async {
            await configuration.batteryHost(network: .testnet)
        }
    }
}

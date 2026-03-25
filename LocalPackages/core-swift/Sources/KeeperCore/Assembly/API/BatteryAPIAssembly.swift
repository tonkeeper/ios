import Foundation

final class BatteryAPIAssembly {
    let configurationAssembly: ConfigurationAssembly

    init(configurationAssembly: ConfigurationAssembly) {
        self.configurationAssembly = configurationAssembly
    }

    // MARK: - Internal

    var apiProvider: BatteryAPIProvider {
        BatteryAPIProvider { [testnetAPI, api] network in
            switch network {
            case .mainnet: return api
            case .testnet: return testnetAPI
            case .tetra: return nil
            }
        }
    }

    lazy var api: BatteryAPI = BatteryAPI(
        hostProvider: batteryApiHostProvider,
        urlSession: URLSession(configuration: urlSessionConfiguration)
    )

    lazy var testnetAPI: BatteryAPI = BatteryAPI(
        hostProvider: testnetBatteryTonApiHostProvider,
        urlSession: URLSession(configuration: urlSessionConfiguration)
    )

    private var batteryApiHostProvider: APIHostProvider {
        MainnetBatteryAPIHostProvider(configuration: configurationAssembly.configuration)
    }

    private var testnetBatteryTonApiHostProvider: APIHostProvider {
        TestnetBatteryAPIHostProvider(configuration: configurationAssembly.configuration)
    }

    private var urlSessionConfiguration: URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 60
        return configuration
    }
}

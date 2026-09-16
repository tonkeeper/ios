import Foundation

final class TradingAPIAssembly {
    let configurationAssembly: ConfigurationAssembly

    init(configurationAssembly: ConfigurationAssembly) {
        self.configurationAssembly = configurationAssembly
    }

    lazy var api: TradingAPI = TradingAPIImplementation(
        hostProvider: tradingAPIHostProvider,
        urlSession: URLSession(configuration: urlSessionConfiguration)
    )

    private var tradingAPIHostProvider: APIHostProvider {
        TradingApiHostProvider(
            configuration: configurationAssembly.configuration
        )
    }

    private var urlSessionConfiguration: URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 60
        return configuration
    }
}

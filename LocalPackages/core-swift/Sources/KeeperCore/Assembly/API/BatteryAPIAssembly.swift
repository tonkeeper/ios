import Foundation
import TonAPI
import TonStreamingAPI
import TonConnectAPI
import StreamURLSessionTransport
import EventSource
import OpenAPIRuntime

final class BatteryAPIAssembly {
  
  let configurationAssembly: ConfigurationAssembly

  init(configurationAssembly: ConfigurationAssembly) {
    self.configurationAssembly = configurationAssembly
  }
  
  // MARK: - Internal
  
  var apiProvider: BatteryAPIProvider {
    BatteryAPIProvider { [testnetAPI, api] isTestnet in
      isTestnet ? testnetAPI : api
    }
  }
  
  lazy var api: BatteryAPI = {
    return BatteryAPI(
      hostProvider: batteryApiHostProvider,
      urlSession: URLSession(
        configuration: urlSessionConfiguration
      ),
      configuration: configurationAssembly.configuration,
      requestCreationQueue: apiRequestCreationQueue
    )
  }()
  
  lazy var testnetAPI: BatteryAPI = {
    return BatteryAPI(
      hostProvider: testnetBatteryTonApiHostProvider,
      urlSession: URLSession(
        configuration: urlSessionConfiguration
      ),
      configuration: configurationAssembly.configuration,
      requestCreationQueue: apiRequestCreationQueue
    )
  }()

  private lazy var apiRequestCreationQueue = DispatchQueue(label: "APIRequestCreationQueue")
    
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


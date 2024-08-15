import Foundation
import TonAPI
import TonStreamingAPI
import TonConnectAPI
import StreamURLSessionTransport
import EventSource
import OpenAPIRuntime

final class APIAssembly {
  
  let configurationAssembly: ConfigurationAssembly

  init(configurationAssembly: ConfigurationAssembly) {
    self.configurationAssembly = configurationAssembly
  }
  
  // MARK: - Internal
  
  var apiProvider: APIProvider {
    APIProvider { [testnetAPI, api] isTestnet in
      isTestnet ? testnetAPI : api
    }
  }
  
  var api: API {
    API(
      hostProvider: tonApiHostProvider,
      urlSession: URLSession(
        configuration: urlSessionConfiguration
      ),
      configurationStore: configurationAssembly.remoteConfigurationStore,
      requestBuilderActor: requestBuilderActor
    )
  }
  
  var testnetAPI: API {
    API(
      hostProvider: testnetTonApiHostProvider,
      urlSession: URLSession(
        configuration: urlSessionConfiguration
      ),
      configurationStore: configurationAssembly.remoteConfigurationStore,
      requestBuilderActor: requestBuilderActor
    )
  }
  
  private lazy var requestBuilderActor = APIRequestBuilderSerialActor()
  
  private var tonApiHostProvider: APIHostProvider {
    MainnetAPIHostProvider(remoteConfigurationStore: configurationAssembly.remoteConfigurationStore)
  }
  
  private var testnetTonApiHostProvider: APIHostProvider {
    TestnetAPIHostProvider(remoteConfigurationStore: configurationAssembly.remoteConfigurationStore)
  }

  private var _streamingTonAPIClient: TonStreamingAPI.Client?
  func streamingTonAPIClient() -> TonStreamingAPI.Client {
    if let streamingTonAPIClient = _streamingTonAPIClient {
      return streamingTonAPIClient
    }
    let streamingTonAPIClient = TonStreamingAPI.Client(
      serverURL: tonAPIURL,
      transport: streamingTransport,
      middlewares: [apiHostProvider, authTokenProvider])
    _streamingTonAPIClient = streamingTonAPIClient
    return streamingTonAPIClient
  }
  
  private var _tonConnectAPIClient: TonConnectAPI.Client?
  func tonConnectAPIClient() -> TonConnectAPI.Client {
    if let tonConnectAPIClient = _tonConnectAPIClient {
      return tonConnectAPIClient
    }
    let tonConnectAPIClient = TonConnectAPI.Client(
      serverURL: (try? TonConnectAPI.Servers.server1()) ?? tonConnectURL,
      transport: streamingTransport,
      middlewares: [])
    _tonConnectAPIClient = tonConnectAPIClient
    return tonConnectAPIClient
  }
  
  // MARK: - Private
  
  private lazy var transport: StreamURLSessionTransport = {
    StreamURLSessionTransport(urlSessionConfiguration: urlSessionConfiguration)
  }()
  
  private lazy var streamingTransport: StreamURLSessionTransport = {
    StreamURLSessionTransport(urlSessionConfiguration: streamingUrlSessionConfiguration)
  }()
  
  private var urlSessionConfiguration: URLSessionConfiguration {
    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = 60
    configuration.timeoutIntervalForResource = 60
    return configuration
  }
  
  private var streamingUrlSessionConfiguration: URLSessionConfiguration {
    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = TimeInterval(Int.max)
    configuration.timeoutIntervalForResource = TimeInterval(Int.max)
    return configuration
  }
  
  private var authTokenProvider: AuthTokenProvider {
    AuthTokenProvider(
      remoteConfigurationStore: configurationAssembly.remoteConfigurationStore
    )
  }
  
  private var apiHostProvider: APIHostUrlProvider {
    APIHostUrlProvider()
  }
  
  var tonAPIURL: URL {
    URL(string: "https://keeper.tonapi.io")!
  }
  
  var testnetTonAPIURL: URL {
    URL(string: "https://testnet.tonapi.io")!
  }
  
  var tonConnectURL: URL {
    URL(string: "https://bridge.tonapi.io/bridge")!
  }
}


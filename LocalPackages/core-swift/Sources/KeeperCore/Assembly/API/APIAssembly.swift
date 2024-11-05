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
  
  lazy var api: API = {
    return API(
      hostProvider: tonApiHostProvider,
      urlSession: URLSession(
        configuration: urlSessionConfiguration
      ),
      configuration: configurationAssembly.configuration,
      requestCreationQueue: apiRequestCreationQueue
    )
  }()
  
  lazy var testnetAPI: API = {
    return API(
      hostProvider: testnetTonApiHostProvider,
      urlSession: URLSession(
        configuration: urlSessionConfiguration
      ),
      configuration: configurationAssembly.configuration,
      requestCreationQueue: apiRequestCreationQueue
    )
  }()
  
  private lazy var apiRequestCreationQueue = DispatchQueue(label: "APIRequestCreationQueue")
    
  private var tonApiHostProvider: APIHostProvider {
    MainnetAPIHostProvider(configuration: configurationAssembly.configuration)
  }
  
  private var testnetTonApiHostProvider: APIHostProvider {
    TestnetAPIHostProvider(configuration: configurationAssembly.configuration)
  }
  
  private var _streamingAPI: StreamingAPI?
  public var streamingAPI: StreamingAPI {
    let isRealtimeHost = true
    if let _streamingAPI {
      return _streamingAPI
    }
    let configuration = configurationAssembly.configuration
    let streamingAPI = StreamingAPI(
      configuration: streamingUrlSessionConfiguration,
      hostProvider: { [streamingAPIURL, tonAPIURL] in
        if isRealtimeHost {
          return streamingAPIURL
        } else {
          let string = await configuration.tonapiV2Endpoint
          guard let url = URL(string: string) else {
            return tonAPIURL
          }
          return url
        }
      },
      tokenProvider: {
        await configuration.tonApiV2Key
      }
    )
    _streamingAPI = streamingAPI
    return streamingAPI
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
  
  private var apiHostProvider: APIHostUrlProvider {
    APIHostUrlProvider()
  }
  
  var tonAPIURL: URL {
    URL(string: "https://keeper.tonapi.io")!
  }
  
  var streamingAPIURL: URL {
    URL(string: "https://rt.tonapi.io")!
  }
  
  var testnetTonAPIURL: URL {
    URL(string: "https://testnet.tonapi.io")!
  }
  
  var tonConnectURL: URL {
    URL(string: "https://bridge.tonapi.io/bridge")!
  }
}

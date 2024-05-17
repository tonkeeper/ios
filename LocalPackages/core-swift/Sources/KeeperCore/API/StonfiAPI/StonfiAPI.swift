import Foundation

struct JsonRpcRequestBody<T: Encodable>: Encodable {
  var jsonrpc: String = "2.0"
  var id: Int = 0
  var method: String
  var params: [String : T]
}

enum StonfiJsonRpcMethods: String {
  case getAssetsList = "asset.list"
  case getAssetsBalances = "asset.balance_list"
  case getAssetsInfo = "asset.info"
  case getSwapPairsList = "market.list"
  case getSwapOperationStatus = "dex.swap_status"
  case simulateDirectSwap = "dex.simulate_swap"
  case simulateReverseSwap = "dex.reverse_simulate_swap"
  
  func createHttpBodyWithoutParameters() -> Data? {
    let requestBody: JsonRpcRequestBody<String> = createRequestBody(parameters: [:])
    return try? JSONEncoder().encode(requestBody)
  }
  
  func createHttpBody<T: Encodable>(parameters: Dictionary<String, T>) throws -> Data? {
    let requestBody = createRequestBody(parameters: parameters)
    return try JSONEncoder().encode(requestBody)
  }
  
  func createRequestBody<T: Encodable>(parameters: Dictionary<String, T> = [:]) -> JsonRpcRequestBody<T> {
    JsonRpcRequestBody(
      method: rawValue,
      params: parameters
    )
  }
}

struct StonfiAPI {
  enum APIError: Swift.Error {
    case incorrectResponse
    case serverError(statusCode: Int)
  }
  
  private let urlSession: URLSession
  private let configurationStore: ConfigurationStore
  
  init(urlSession: URLSession, configurationStore: ConfigurationStore) {
    self.urlSession = urlSession
    self.configurationStore = configurationStore
  }
}

// MARK: - Get Assets

extension StonfiAPI {
  private struct StonfiAssetsResponseRpc: Codable {
    let assetList: [StonfiAsset]
    
    enum RootCodingKeys: String, CodingKey {
      case result
    }
    
    enum ResultCodingKeys: String, CodingKey {
      case assets
    }
    
    init(from decoder: any Decoder) throws {
      let rootContainer = try decoder.container(keyedBy: RootCodingKeys.self)
      let resultsContainer = try rootContainer.nestedContainer(keyedBy: ResultCodingKeys.self, forKey: .result)
      self.assetList = try resultsContainer.decode([StonfiAsset].self, forKey: .assets)
    }
  }
  
  func getStonfiAssets() async throws -> [StonfiAsset] {
    let configuration = try await configurationStore.getConfiguration()
    guard var components = URLComponents(string: configuration.stonfiJsonRpcEndpoint) else { return [] }
    components.path = "/rpc"
    
    guard let url = components.url else { return [] }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try StonfiJsonRpcMethods.getAssetsList.createHttpBody(parameters: [
      "load_community" : false
    ])
    
    let (data, response) = try await urlSession.data(for: request)
    guard let httpResponse = (response as? HTTPURLResponse) else {
      throw APIError.incorrectResponse
    }
    guard (200..<300).contains(httpResponse.statusCode) else {
      throw APIError.serverError(statusCode: httpResponse.statusCode)
    }
    
    let stonfiAssetsResponse = try JSONDecoder().decode(StonfiAssetsResponseRpc.self, from: data)
    return stonfiAssetsResponse.assetList
  }
}

// MARK: - Get Pairs

extension StonfiAPI {
  private struct StonfiPairsResponse: Codable {
    let pairs: [[String]]
    
    enum RootCodingKeys: String, CodingKey {
      case result
    }
    
    enum ResultCodingKeys: String, CodingKey {
      case pairs
    }
    
    init(from decoder: any Decoder) throws {
      let rootContainer = try decoder.container(keyedBy: RootCodingKeys.self)
      let resultsContainer = try rootContainer.nestedContainer(keyedBy: ResultCodingKeys.self, forKey: .result)
      self.pairs = try resultsContainer.decode([[String]].self, forKey: .pairs)
    }
  }
  
  func getStonfiPairs() async throws -> [[String]] {
    let configuration = try await configurationStore.getConfiguration()
    guard var components = URLComponents(string: configuration.stonfiJsonRpcEndpoint) else { return [] }
    components.path = "/rpc"
    
    guard let url = components.url else { return [] }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = StonfiJsonRpcMethods.getSwapPairsList.createHttpBodyWithoutParameters()
    
    let (data, response) = try await urlSession.data(for: request)
    guard let httpResponse = (response as? HTTPURLResponse) else {
      throw APIError.incorrectResponse
    }
    guard (200..<300).contains(httpResponse.statusCode) else {
      throw APIError.serverError(statusCode: httpResponse.statusCode)
    }
    
    let stonfiPairsResponse = try JSONDecoder().decode(StonfiPairsResponse.self, from: data)
    return stonfiPairsResponse.pairs
  }
}

import Foundation
import TonSwift
import BigInt

struct JsonRpcResponse<T: Decodable>: Decodable {
  let result: T
}

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
  private struct StonfiAssetsResult: Decodable {
    let assets: [StonfiAsset]
  }
  
  func getStonfiAssets() async throws -> [StonfiAsset] {
    let configuration = try await configurationStore.getConfiguration()
    guard var components = URLComponents(string: configuration.stonfiJsonRpcEndpoint) else { return [] }
    components.path = "/rpc"
    
    guard let url = components.url else { return [] }
    
    let request = try createJsonRpcRequest(
      url: url,
      method: .getAssetsList,
      parameters: ["load_community" : false]
    )
    
    let (data, response) = try await urlSession.data(for: request)
    guard let httpResponse = (response as? HTTPURLResponse) else {
      throw APIError.incorrectResponse
    }
    guard (200..<300).contains(httpResponse.statusCode) else {
      throw APIError.serverError(statusCode: httpResponse.statusCode)
    }
    
    let stonfiAssetsResponse = try JSONDecoder().decode(JsonRpcResponse<StonfiAssetsResult>.self, from: data)
    return stonfiAssetsResponse.result.assets
  }
}

// MARK: - Get Assets Info

extension StonfiAPI {
  func getAssetsInfo(addresses: [Address]) async throws -> [StonfiAsset] {
    let configuration = try await configurationStore.getConfiguration()
    guard var components = URLComponents(string: configuration.stonfiJsonRpcEndpoint) else { return [] }
    components.path = "/rpc"
    
    guard let url = components.url else { return [] }
    
    let parameters = ["addresses" : addresses.map({ $0.toString() })]
    
    let request = try createJsonRpcRequest(
      url: url,
      method: .getAssetsInfo,
      parameters: parameters
    )
    
    let (data, response) = try await urlSession.data(for: request)
    guard let httpResponse = (response as? HTTPURLResponse) else {
      throw APIError.incorrectResponse
    }
    guard (200..<300).contains(httpResponse.statusCode) else {
      throw APIError.serverError(statusCode: httpResponse.statusCode)
    }
    
    let stonfiAssetsResponse = try JSONDecoder().decode(JsonRpcResponse<StonfiAssetsResult>.self, from: data)
    return stonfiAssetsResponse.result.assets
  }
}

// MARK: - Get Pairs

extension StonfiAPI {
  private struct StonfiPairsResult: Decodable {
    let pairs: [[String]]
  }
  
  func getStonfiPairs() async throws -> [[String]] {
    let configuration = try await configurationStore.getConfiguration()
    guard var components = URLComponents(string: configuration.stonfiJsonRpcEndpoint) else { return [] }
    components.path = "/rpc"
    
    guard let url = components.url else { return [] }
    
    let request = try createJsonRpcRequest(
      url: url,
      method: .getSwapPairsList
    )
    
    let (data, response) = try await urlSession.data(for: request)
    guard let httpResponse = (response as? HTTPURLResponse) else {
      throw APIError.incorrectResponse
    }
    guard (200..<300).contains(httpResponse.statusCode) else {
      throw APIError.serverError(statusCode: httpResponse.statusCode)
    }
    
    let stonfiPairsResponse = try JSONDecoder().decode(JsonRpcResponse<StonfiPairsResult>.self, from: data)
    return stonfiPairsResponse.result.pairs
  }
}

// MARK: - Simulate Swap

extension StonfiAPI {
  func simulateDirectSwap(from: Address, to: Address, offerAmount: BigUInt, slippageTolerance: String, referral: Address? = nil) async throws -> StonfiSwapSimulationResult {
    let configuration = try await configurationStore.getConfiguration()
    guard var components = URLComponents(string: configuration.stonfiJsonRpcEndpoint) else { return StonfiSwapSimulationResult() }
    components.path = "/rpc"
    
    guard let url = components.url else { return StonfiSwapSimulationResult() }
    
    var parameters = [
      "offer_address" : from.toString(),
      "offer_units" : offerAmount.description,
      "ask_address" : to.toString(),
      "slippage_tolerance" : slippageTolerance
    ]
    if let referral {
      parameters.updateValue(referral.toString(), forKey: "referral_address")
    }
    
    let request = try createJsonRpcRequest(
      url: url,
      method: .simulateDirectSwap,
      parameters: parameters
    )
    
    let (data, response) = try await urlSession.data(for: request)
    guard let httpResponse = (response as? HTTPURLResponse) else {
      throw APIError.incorrectResponse
    }
    guard (200..<300).contains(httpResponse.statusCode) else {
      throw APIError.serverError(statusCode: httpResponse.statusCode)
    }
    
    let directSwapSimulationResponse = try JSONDecoder().decode(JsonRpcResponse<StonfiSwapSimulationResult>.self, from: data)
    return directSwapSimulationResponse.result
  }
  
  func simulateReverseSwap(from: Address, to: Address, askAmount: BigUInt, slippageTolerance: String, referral: Address? = nil) async throws -> StonfiSwapSimulationResult {
    let configuration = try await configurationStore.getConfiguration()
    guard var components = URLComponents(string: configuration.stonfiJsonRpcEndpoint) else { return StonfiSwapSimulationResult() }
    components.path = "/rpc"
    
    guard let url = components.url else { return StonfiSwapSimulationResult() }
    
    var parameters = [
      "offer_address" : from.toString(),
      "ask_units" : askAmount.description,
      "ask_address" : to.toString(),
      "slippage_tolerance" : slippageTolerance
    ]
    if let referral {
      parameters.updateValue(referral.toString(), forKey: "referral_address")
    }
    
    let request = try createJsonRpcRequest(
      url: url,
      method: .simulateReverseSwap,
      parameters: parameters
    )
    
    let (data, response) = try await urlSession.data(for: request)
    guard let httpResponse = (response as? HTTPURLResponse) else {
      throw APIError.incorrectResponse
    }
    guard (200..<300).contains(httpResponse.statusCode) else {
      throw APIError.serverError(statusCode: httpResponse.statusCode)
    }
    
    let directSwapSimulationResponse = try JSONDecoder().decode(JsonRpcResponse<StonfiSwapSimulationResult>.self, from: data)
    return directSwapSimulationResponse.result
  }
}

private extension StonfiAPI {
  func createJsonRpcRequest(url: URL, method: StonfiJsonRpcMethods) throws -> URLRequest {
    return try createJsonRpcRequest(url: url, method: method, parameters: [String : String]())
  }
  
  func createJsonRpcRequest<T: Encodable>(url: URL,
                                          method: StonfiJsonRpcMethods,
                                          parameters: Dictionary<String, T>) throws -> URLRequest {
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try createHttpBody(method: method, parameters: parameters)
    return request
  }
  
  func createHttpBody<T: Encodable>(method: StonfiJsonRpcMethods, parameters: Dictionary<String, T>) throws -> Data? {
    let requestBody = createRequestBody(method: method, parameters: parameters)
    return try JSONEncoder().encode(requestBody)
  }
  
  func createRequestBody<T: Encodable>(method: StonfiJsonRpcMethods, parameters: Dictionary<String, T> = [:]) -> JsonRpcRequestBody<T> {
    JsonRpcRequestBody(
      method: method.rawValue,
      params: parameters
    )
  }
}

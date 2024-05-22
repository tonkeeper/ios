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
  private struct StonfiAssetsResult: Decodable {
    let assets: [StonfiAsset]
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
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try StonfiJsonRpcMethods.getAssetsInfo.createHttpBody(parameters: [
      "addresses" : addresses.map({ $0.toString() })
    ])
    
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
    
    let stonfiPairsResponse = try JSONDecoder().decode(JsonRpcResponse<StonfiPairsResult>.self, from: data)
    return stonfiPairsResponse.result.pairs
  }
}

// MARK: - Simulate Swap

struct StonfiSwapSimulation {
  let offerAddress: Address
  let askAddress: Address
  let routerAddress: Address
  let poolAddress: Address
  let offerUnits: BigUInt
  let askUnits: BigUInt
  let slippageTolerance: String
  let minAskUnits: BigUInt
  let swapRate: Decimal
  let priceImpact: Decimal
  let feeAddress: Address
  let feeUnits: BigUInt
  let feePercent: String
}

struct StonfiSwapSimulationResult: Codable {
  let offerAddress: String
  let askAddress: String
  let routerAddress: String
  let poolAddress: String
  let offerUnits: String
  let askUnits: String
  let slippageTolerance: String
  let minAskUnits: String
  let swapRate: String
  let priceImpact: String
  let feeAddress: String
  let feeUnits: String
  let feePercent: String
  
  enum CodingKeys: String, CodingKey {
    case offerAddress = "offer_address"
    case askAddress = "ask_address"
    case routerAddress = "router_address"
    case poolAddress = "pool_address"
    case offerUnits = "offer_units"
    case askUnits = "ask_units"
    case slippageTolerance = "slippage_tolerance"
    case minAskUnits = "min_ask_units"
    case swapRate = "swap_rate"
    case priceImpact = "price_impact"
    case feeAddress = "fee_address"
    case feeUnits = "fee_units"
    case feePercent = "fee_percent"
  }
}

extension StonfiSwapSimulationResult {
  init() {
    self.offerAddress = ""
    self.askAddress = ""
    self.routerAddress = ""
    self.poolAddress = ""
    self.offerUnits = ""
    self.askUnits = ""
    self.slippageTolerance = ""
    self.minAskUnits = ""
    self.swapRate = ""
    self.priceImpact = ""
    self.feeAddress = ""
    self.feeUnits = ""
    self.feePercent = ""
  }
}

extension StonfiAPI {
  func simulateDirectSwap(from: Address, to: Address, offerAmount: BigUInt, slippageTolerance: String, referral: Address? = nil) async throws -> StonfiSwapSimulationResult {
    let configuration = try await configurationStore.getConfiguration()
    guard var components = URLComponents(string: configuration.stonfiJsonRpcEndpoint) else { return StonfiSwapSimulationResult() }
    components.path = "/rpc"
    
    guard let url = components.url else { return StonfiSwapSimulationResult() }
    
    let offerAddress = from.toString()
    let askAddress = to.toString()
    //let referralAddress = referral?.toString() ?? ""
    
    let offerUnits = offerAmount.description
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try StonfiJsonRpcMethods.simulateDirectSwap.createHttpBody(parameters: [
      "offer_address" : offerAddress,
      "offer_units" : offerUnits,
      "ask_address" : askAddress,
      "slippage_tolerance" : slippageTolerance
    ])
    
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
    
    let offerAddress = from.toString()
    let askAddress = to.toString()
    //let referralAddress = referral?.toString() ?? ""
    
    let askUnits = askAmount.description
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try StonfiJsonRpcMethods.simulateReverseSwap.createHttpBody(parameters: [
      "offer_address" : offerAddress,
      "ask_units" : askUnits,
      "ask_address" : askAddress,
      "slippage_tolerance" : slippageTolerance
    ])
    
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

import Foundation

enum StonFiAPIError: Swift.Error {
  case incorrectHost(String)
}

protocol StonFiAPI {
  func getAssets() async throws -> AssetList
  func getPairs() async throws -> PairsList
  func swapSimulate(offerAddress: String, askAddress: String, units: String, slippageTolerance: Float) async throws -> SwapEstimate
  func reverseSwapSimulate(offerAddress: String, askAddress: String, units: String, slippageTolerance: Float) async throws -> SwapEstimate
}

final class StonFiAPIImplementation: StonFiAPI {
  private let urlSession: URLSession
  
  init(urlSession: URLSession) {
    self.urlSession = urlSession
  }
  
  func getAssets() async throws -> AssetList {
    guard let hostURL = URL(string: .stonFiAPIHost) else {
      throw StonFiAPIError.incorrectHost(.stonFiAPIHost)
    }
    
    let url = hostURL
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    let parameters: [String: Any] = [
      "jsonrpc": "2.0",
      "id": 1,
      "method": "asset.list",
      "params": [:]
    ]
    let jsonData = try! JSONSerialization.data(withJSONObject: parameters, options: [])
    request.httpBody = jsonData
    let (data, _) = try await urlSession.data(for: request)
    var entity = try JSONDecoder().decode(AssetList.self, from: data)
    entity.result.assets = entity.result.assets.sorted(by: { a, b in
      a.symbol.lowercased() < b.symbol.lowercased()
    })
    return entity
  }
  
  func getPairs() async throws -> PairsList {
    guard let hostURL = URL(string: .stonFiAPIHost) else {
      throw StonFiAPIError.incorrectHost(.stonFiAPIHost)
    }
    let url = hostURL
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    let parameters: [String: Any] = [
      "jsonrpc": "2.0",
      "id": 1,
      "method": "market.list",
      "params": [:]
    ]
    let jsonData = try! JSONSerialization.data(withJSONObject: parameters, options: [])
    request.httpBody = jsonData
    let (data, _) = try await urlSession.data(for: request)
    let entity = try JSONDecoder().decode(PairsList.self, from: data)
    return entity
  }
  
  func swapSimulate(offerAddress: String, askAddress: String, units: String, slippageTolerance: Float) async throws -> SwapEstimate {
    guard let hostURL = URL(string: .stonFiAPIHost) else {
      throw StonFiAPIError.incorrectHost(.stonFiAPIHost)
    }

    let url = hostURL
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    let parameters: [String: Any] = [
      "jsonrpc": "2.0",
      "id": 1,
      "method": "dex.simulate_swap",
      "params": [
        "offer_address": offerAddress,
        "ask_address": askAddress,
        "offer_units": "\(units)",
        "slippage_tolerance": "\(slippageTolerance / 100)"
      ]
    ]
    let jsonData = try! JSONSerialization.data(withJSONObject: parameters, options: [])
    request.httpBody = jsonData
    let (data, _) = try await urlSession.data(for: request)
    let entity = try JSONDecoder().decode(SwapEstimateResponse.self, from: data)
    return entity.result
  }
  
  func reverseSwapSimulate(offerAddress: String, askAddress: String, units: String, slippageTolerance: Float) async throws -> SwapEstimate {
    guard let hostURL = URL(string: .stonFiAPIHost) else {
      throw StonFiAPIError.incorrectHost(.stonFiAPIHost)
    }
    
    let url = hostURL
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    let parameters: [String: Any] = [
      "jsonrpc": "2.0",
      "id": 1,
      "method": "dex.reverse_simulate_swap",
      "params": [
        "offer_address": offerAddress,
        "ask_address": askAddress,
        "ask_units": "\(units)",
        "slippage_tolerance": "\(slippageTolerance / 100)"
      ]
    ]
    let jsonData = try! JSONSerialization.data(withJSONObject: parameters, options: [])
    request.httpBody = jsonData
    let (data, _) = try await urlSession.data(for: request)
    let entity = try JSONDecoder().decode(SwapEstimateResponse.self, from: data)
    return entity.result
  }
}

private extension String {
  static let stonFiAPIHost = "https://app.ston.fi/rpc"
}

import Foundation

protocol ScamAPI {
  func changeSuspiciousState(_ nft: NFT, isScam: Bool, isTestnet: Bool) async throws
}

extension ScamAPI {
  func changeSuspiciousState(_ nft: NFT, isScam: Bool) async throws {
    try await changeSuspiciousState(nft, isScam: isScam, isTestnet: false)
  }
}

struct ScamAPIImplementation: ScamAPI {
  
  private let urlSession: URLSession
  private let configuration: Configuration
  
  init(urlSession: URLSession,
       configuration: Configuration) {
    self.urlSession = urlSession
    self.configuration = configuration
  }
  
  enum ScamNFTRequestURL: Swift.Error {
    case incorrectURL
  }

  private struct SuspiciousNFT: Codable {
    let is_scam: Bool
  }

  func changeSuspiciousState(_ nft: NFT, isScam: Bool, isTestnet: Bool = false) async throws {
    guard let scamAPIUrl = await configuration.scamApiURL(isTestnet: isTestnet) else {
      throw ScamNFTRequestURL.incorrectURL
    }
    var composedURL = scamAPIUrl
    let rawAddress = nft.address.toRaw()
    composedURL = composedURL.appendingPathComponent("v1/report/\(rawAddress)")
    let bodyItem = SuspiciousNFT(is_scam: isScam)
    let encoder = JSONEncoder()

    let httpBody = try encoder.encode(bodyItem)
    
    var request = URLRequest(url: composedURL)
    request.httpMethod = "POST"
    request.httpBody = httpBody
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    let _ = try await urlSession.data(for: request)
  }

}

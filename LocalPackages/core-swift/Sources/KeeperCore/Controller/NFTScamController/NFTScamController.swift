import Foundation

public final class NFTScamController {

  struct SuspiciousNFT: Codable {
    let is_scam: Bool
  }

  private let configuration: Configuration
  private let nft: NFT

  init(configuration: Configuration, nft: NFT) {
    self.configuration = configuration
    self.nft = nft
  }

  public func changeSuspiciousState(isScam: Bool) async throws {
    var composedURL = configuration.scamApiURL
    let rawAddress = nft.address.toRaw()
    composedURL = composedURL?.appendingPathComponent("v1/report/\(rawAddress)")
    let encoded = SuspiciousNFT(is_scam: isScam)
    let encoder = JSONEncoder()

    guard let composedURL, let httpBody = try? encoder.encode(encoded) else {
      return
    }

    var request = URLRequest(url: composedURL)
    request.httpMethod = "POST"
    request.httpBody = httpBody
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    let _ = try await URLSession.shared.data(for: request)
  }
}

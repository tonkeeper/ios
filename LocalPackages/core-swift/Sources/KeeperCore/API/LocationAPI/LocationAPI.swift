import Foundation

enum LocationAPIError: Swift.Error {
  case incorrectHost(String)
}

protocol LocationAPI {
  func loadRegionByIP() async throws -> RegionByIP
}

final class IpApiAPIImplementation: LocationAPI {
  private let urlSession: URLSession
  
  init(urlSession: URLSession) {
    self.urlSession = urlSession
  }
  
  func loadRegionByIP() async throws -> RegionByIP {
    guard let hostURL = URL(string: .ipAPIHost) else {
      throw LocationAPIError.incorrectHost(.ipAPIHost)
    }
    
    let url = hostURL.appendingPathComponent("json")
    let (data, _) = try await urlSession.data(from: url)
    let entity = try JSONDecoder().decode(RegionByIP.self, from: data)
    return entity
  }
}

private extension String {
  static let ipAPIHost = "http://ip-api.com"
}

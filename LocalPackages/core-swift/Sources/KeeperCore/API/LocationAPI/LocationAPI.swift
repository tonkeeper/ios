import Foundation

enum LocationAPIError: Swift.Error {
    case incorrectHost(String)
}

protocol LocationAPI {
    func loadRegionByIP() async throws -> RegionByIP
}

private extension String {
    static let ipAPIHost = "http://ip-api.com"
}

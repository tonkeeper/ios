import Foundation

public protocol LocationService {
    func getCountryCodeByIp() async throws -> String
}

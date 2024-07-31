import Foundation

public protocol LocationService {
  func getCountryCodeByIp() async throws -> String
}

final class LocationServiceImplementation: LocationService {
  private let locationAPI: LocationAPI
  
  init(locationAPI: LocationAPI) {
    self.locationAPI = locationAPI
  }
  
  func getCountryCodeByIp() async throws -> String {
    return try await locationAPI.loadRegionByIP().countryCode
  }
}

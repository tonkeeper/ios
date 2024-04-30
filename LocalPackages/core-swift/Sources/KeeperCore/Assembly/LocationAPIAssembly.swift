import Foundation

final class LocationAPIAssembly {
  
  private var _locationAPI: LocationAPI?
  func locationAPI() -> LocationAPI {
    if let locationAPI = _locationAPI {
      return locationAPI
    }
    let locationAPI = IpApiAPIImplementation(urlSession: .shared)
    _locationAPI = locationAPI
    return locationAPI
  }
}


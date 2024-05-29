import Foundation

final class StonFiAPIAssembly {
  
  private var _stonFiAPI: StonFiAPI?
  func stonFiAPI() -> StonFiAPI {
    if let stonFiAPI = _stonFiAPI {
      return stonFiAPI
    }
    let stonFiAPI = StonFiAPIImplementation(urlSession: .shared)
    _stonFiAPI = stonFiAPI
    return stonFiAPI
  }
}


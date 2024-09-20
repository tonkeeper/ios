import Foundation

public enum TonsignDeeplink {
  case plain
  
  public var string: String {
    let tonsign = "tonsign"
    switch self {
    case .plain:
      var components = URLComponents()
      components.scheme = tonsign
      return components.string ?? ""
    }
  }
}

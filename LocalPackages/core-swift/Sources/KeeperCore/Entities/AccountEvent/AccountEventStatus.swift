import Foundation

enum AccountEventStatus: Codable {
  case ok
  case failed
  case unknown(String)
  
  var rawValue: String? {
    switch self {
    case .ok: return nil
    case .failed: return "Failed"
    case .unknown(let value):
      return value
    }
  }
  
  init(rawValue: String) {
    switch rawValue {
    case "ok": self = .ok
    case "failed": self = .failed
    default: self = .unknown(rawValue)
    }
  }
}

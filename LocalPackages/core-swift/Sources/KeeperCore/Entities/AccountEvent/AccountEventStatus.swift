import Foundation
import TKLocalize

public enum AccountEventStatus: Codable {
  case ok
  case failed
  case unknown(String)
  
  public var rawValue: String? {
    switch self {
    case .ok: return nil
    case .failed: return TKLocales.Actions.failed
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

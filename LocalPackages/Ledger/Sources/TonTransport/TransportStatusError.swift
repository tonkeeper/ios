import Foundation

public enum TransportStatusError: Error, LocalizedError {
  case incorrectLength
  case missingCriticalParameter
  case securityNotSatisfied
  case deniedByUser
  case invalidDataReceived
  case invalidParameterReceived
  case lockedDevice
  case internalError
  case unknownError(code: UInt16)
  
  public var errorDescription: String? {
    switch self {
    case .incorrectLength:
      return "Incorrect length"
    case .missingCriticalParameter:
      return "Missing critical parameter"
    case .securityNotSatisfied:
      return "Security not satisfied (dongle locked or have invalid access rights)"
    case .deniedByUser:
      return "Condition of use not satisfied (denied by the user?)"
    case .invalidDataReceived:
      return "Invalid data received"
    case .invalidParameterReceived:
      return "Invalid parameter received"
    case .lockedDevice:
      return "Locked device"
    case .internalError:
      return "Internal error, please report"
    case .unknownError(let code):
      return "Unknown error with status code: \(code)"
    }
  }
  
  public static func fromStatusCode(_ statusCode: UInt16) -> TransportStatusError {
    switch statusCode {
    case 0x6700:
      return .incorrectLength
    case 0x6800:
      return .missingCriticalParameter
    case 0x6982:
      return .securityNotSatisfied
    case 0x6985:
      return .deniedByUser
    case 0x6a80:
      return .invalidDataReceived
    case 0x6b00:
      return .invalidParameterReceived
    case 0x5515:
      return .lockedDevice
    case 0x6f00...0x6fff:
      return .internalError
    default:
      return .unknownError(code: statusCode)
    }
  }
}

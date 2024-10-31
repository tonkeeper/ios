import Foundation

enum TonSignatureError: Error {
  case invalidCBORType
}

public struct TonSignature: Equatable {
  public enum KEYS: UInt64 {
    case requestId = 1
    case signature = 2
    case origin = 3
  }
  
  public var signature: Data? = nil
  public var requestId: Data? = nil
  public var origin: String? = nil
  
  public init(cbor: CBOR) throws {
    switch cbor {
    case .map(let map):
      for (key, value) in map {
        let keyUint = try UInt64(cbor: key)
        if (keyUint == KEYS.signature.rawValue) {
          signature = try Data(cbor: value)
        }
        if (keyUint == KEYS.requestId.rawValue) {
          requestId = try Data(cbor: value)
        }
        if (keyUint == KEYS.origin.rawValue) {
          origin = try String(cbor: value)
        }
      }
    default:
      throw TonSignatureError.invalidCBORType
    }
  }
}

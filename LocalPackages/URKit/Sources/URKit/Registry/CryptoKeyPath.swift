import Foundation

enum CryptoKeyPathError: Error {
  case invalidCBORType
}

public struct CryptoKeyPath: Equatable {
  public enum KEYS: UInt64 {
    case components = 1
    case sourceFingerprint = 2
    case depth = 3
  }
  
  public var components: CryptoPath? = nil
  public var sourceFingerprint: UInt64? = nil
  public var depth: UInt64? = nil
  
  public init(components: CryptoPath?, sourceFingerprint: UInt64?, depth: UInt64?) {
    self.components = components
    self.sourceFingerprint = sourceFingerprint
    self.depth = depth
  }
  
  public init(cbor: CBOR) throws {
    switch cbor {
    case .map(let map):
      for (key, value) in map {
        let keyUint = try UInt64(cbor: key)
        if (keyUint == KEYS.components.rawValue) {
          components = try CryptoPath.init(cbor: value)
        }
        if (keyUint == KEYS.sourceFingerprint.rawValue) {
          sourceFingerprint = try UInt64(cbor: value)
        }
        if (keyUint == KEYS.depth.rawValue) {
          depth = try UInt64(cbor: value)
        }
      }
    default:
      throw CryptoKeyPathError.invalidCBORType
    }
  }
  
  public func toCBOR() throws -> CBOR {
    var map = Map()
    if let components = components {
      map[CBOR.unsigned(KEYS.components.rawValue)] = CBOR.array(components.components)
    }
    if let sourceFingerprint = sourceFingerprint {
      map[CBOR.unsigned(KEYS.sourceFingerprint.rawValue)] = CBOR.unsigned(sourceFingerprint)
    }
    if let depth = depth {
      map[CBOR.unsigned(KEYS.depth.rawValue)] = CBOR.unsigned(depth)
    }
    return CBOR.tagged(Tag.init(304, ["crypto-keypath"]), CBOR.map(map))
  }
}

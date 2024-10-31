import Foundation

enum CryptoHDKeyError: Error {
  case invalidCBORType
}

public struct CryptoHDKey: Equatable {
  public enum KEYS: UInt64 {
    case masterKey = 1
    case privateKey = 2
    case keyData = 3
    case chainCode = 4
    case useInfo = 5
    case origin = 6
    case children = 7
    case parentFingerprint = 8
    case name = 9
    case note = 10
  }
  
  public var masterKey: Bool? = false
  public var privateKey: Bool? = nil
  public var keyData: Data? = nil
  public var chainCode: Data? = nil
  public var useInfo: Data? = nil
  public var origin: CryptoKeyPath? = nil
  public var children: CryptoKeyPath? = nil
  public var parentFingerprint: Data? = nil
  public var name: String? = nil
  public var note: String? = nil
  
  public init(cbor: CBOR) throws {
    switch cbor {
    case .map(let map):
      for (key, value) in map {
        let keyUint = try UInt64(cbor: key)
        if (keyUint == KEYS.masterKey.rawValue) {
          masterKey = try Bool(cbor: value)
        }
        if (keyUint == KEYS.privateKey.rawValue) {
          privateKey = try Bool(cbor: value)
        }
        if (keyUint == KEYS.keyData.rawValue) {
          keyData = try Data(cbor: value)
        }
        if (keyUint == KEYS.chainCode.rawValue) {
          chainCode = try Data(cbor: value)
        }
        if (keyUint == KEYS.useInfo.rawValue) {
          useInfo = try Data(cbor: value)
        }
        if (keyUint == KEYS.origin.rawValue) {
          switch (value) {
          case.tagged(_, let keyPath):
            origin = try CryptoKeyPath.init(cbor: keyPath)
          default:
            throw CryptoHDKeyError.invalidCBORType
          }
        }
        if (keyUint == KEYS.children.rawValue) {
          switch (value) {
          case.tagged(_, let keyPath):
            children = try CryptoKeyPath.init(cbor: keyPath)
          default:
            throw CryptoHDKeyError.invalidCBORType
          }
        }
        if (keyUint == KEYS.parentFingerprint.rawValue) {
          parentFingerprint = try Data(cbor: value)
        }
        if (keyUint == KEYS.name.rawValue) {
          name = try String(cbor: value)
        }
        if (keyUint == KEYS.note.rawValue) {
          note = try String(cbor: value)
        }
      }
    default:
      throw CryptoHDKeyError.invalidCBORType
    }
  }
}

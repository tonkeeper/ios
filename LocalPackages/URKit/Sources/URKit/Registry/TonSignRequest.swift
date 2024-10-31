import Foundation

public enum TonSignRequestError: Error {
  case invalidCBORType
}

public struct TonSignRequest: Equatable {
  public enum KEYS: UInt64 {
    case requestId = 1
    case signData = 2
    case dataType = 3
    case cryptoKeypath = 4
    case address = 5
    case origin = 6
  }
  
  public var requestId: Data? = nil
  public var signData: Data? = nil
  public var dataType: UInt64? = nil
  public var cryptoKeypath: CryptoKeyPath? = nil
  public var address: String? = nil
  public var origin: String? = nil
  
  public init(requestId: Data? = nil, signData: Data? = nil, dataType: UInt64? = nil, cryptoKeypath: CryptoKeyPath? = nil, address: String? = nil, origin: String? = nil) {
    self.requestId = requestId
    self.signData = signData
    self.dataType = dataType
    self.cryptoKeypath = cryptoKeypath
    self.address = address
    self.origin = origin
  }
  
  public func toCBOR() throws -> CBOR {
    var map = Map()
    if let requestId = requestId {
      map[CBOR.unsigned(KEYS.requestId.rawValue)] = CBOR.tagged(Tag.init(37, ["uuid"]), CBOR.bytes(requestId))
    }
    if let signData = signData {
      map[CBOR.unsigned(KEYS.signData.rawValue)] = CBOR.bytes(signData)
    }
    if let dataType = dataType {
      map[CBOR.unsigned(KEYS.dataType.rawValue)] = CBOR.unsigned(dataType)
    }
    if let cryptoKeypath = cryptoKeypath {
      map[CBOR.unsigned(KEYS.cryptoKeypath.rawValue)] = try cryptoKeypath.toCBOR()
    }
    if let address = address {
      map[CBOR.unsigned(KEYS.address.rawValue)] = CBOR.text(address)
    }
    if let origin = origin {
      map[CBOR.unsigned(KEYS.origin.rawValue)] = CBOR.text(origin)
    }
    return CBOR.map(map)
  }
}

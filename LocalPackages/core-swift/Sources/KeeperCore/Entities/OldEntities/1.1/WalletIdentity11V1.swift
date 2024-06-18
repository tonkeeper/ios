import Foundation
import TonSwift

extension Version11V1 {
  public struct WalletIdentity: Equatable, Identifiable {
    public let network: Network
    public let kind: Version11V1.WalletKind
    
    public func identifier() throws -> WalletID {
      let builder = Builder()
      try builder.store(self)
      return WalletID(hash: try builder.endCell().representationHash())
    }
    
    public var id: String {
      kind.id + String(network.rawValue)
    }
  }
}

extension Version11V1.WalletIdentity: Codable {
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let identityBinaryString = try container.decode(String.self)
    let identityBitstring = try Bitstring(binaryString: identityBinaryString)
    self = try Slice(bits: identityBitstring).loadType()
  }
  
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    let identityBinaryString = try Builder().store(self).bitstring().toBinary()
    try container.encode(identityBinaryString)
  }
}

extension Version11V1.WalletIdentity: CellCodable {
  public func storeTo(builder: Builder) throws {
    try network.storeTo(builder: builder)
    try kind.storeTo(builder: builder)
  }
  
  public static func loadFrom(slice: Slice) throws -> Version11V1.WalletIdentity {
    return try slice.tryLoad { s in
      let network: Network = try s.loadType()
      let kind: Version11V1.WalletKind = try s.loadType()
      return Version11V1.WalletIdentity(network: network, kind: kind)
    }
  }
}

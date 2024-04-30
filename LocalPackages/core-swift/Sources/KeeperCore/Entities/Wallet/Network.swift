import Foundation
import TonSwift

public enum Network: Int16, Hashable {
  case mainnet = -239
  case testnet = -3
}

extension Network: CellCodable {
  public func storeTo(builder: Builder) throws {
    try builder.store(int: rawValue, bits: .rawValueLength)
  }
  
  public static func loadFrom(slice: Slice) throws -> Network {
    return try slice.tryLoad { s in
      let rawValue = Int16(try s.loadInt(bits: .rawValueLength))
      guard let network = Network(rawValue: rawValue) else {
        throw TonSwift.TonError.custom("Invalid network code")
      }
      return network
    }
  }
}

private extension Int {
  static let rawValueLength = 16
}

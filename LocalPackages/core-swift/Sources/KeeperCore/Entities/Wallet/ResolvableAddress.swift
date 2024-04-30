import Foundation
import TonSwift

/// Human-visible address that can be resolved dynamically
public enum ResolvableAddress: Hashable, Codable {
  /// Raw TON address (e.g. "EQf85gAj...")
  case Resolved(TonSwift.Address)
  /// TON.DNS name (e.g. "oleganza.ton")
  case Domain(String, TonSwift.Address)
}

extension ResolvableAddress: CellCodable {
  public func storeTo(builder: Builder) throws {
    switch self {
    case let .Resolved(address):
      try builder.store(uint: 0, bits: 2)
      try address.storeTo(builder: builder)
    case let .Domain(domain, address):
      try builder.store(uint: 1, bits: 2)
      let domainData = domain.data(using: .utf8) ?? Data()
      try builder.store(uint: domainData.count, bits: .domainDataCountLength)
      try builder.store(data: domainData)
      try address.storeTo(builder: builder)
    }
  }
  public static func loadFrom(slice: Slice) throws -> ResolvableAddress {
    return try slice.tryLoad { s in
      let type = try s.loadUint(bits: 2)
      switch type {
      case 0:
        let address: TonSwift.Address = try s.loadType()
        return .Resolved(address)
      case 1:
        let domainDataCount = Int(try s.loadUint(bits: .domainDataCountLength))
        let domainData = try s.loadBytes(domainDataCount)
        guard let domain = String(data: domainData, encoding: .utf8) else {
          throw TonError.custom("Invalid domain data")
        }
        let address: TonSwift.Address = try s.loadType()
        return .Domain(domain, address)
      default:
        throw TonError.custom("Invalid ResolvableAddress type");
      }
    }
  }
}

private extension Int {
  static let domainDataCountLength = 10
}

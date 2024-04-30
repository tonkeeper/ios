//
//  WalletIdentity.swift
//
//
//  Created by Grigory Serebryanyy on 17.11.2023.
//

import Foundation
import TonSwift

extension Version_1_0_0 {
  struct WalletIdentity {
    let network: Network
    let kind: Version_1_0_0.WalletKind
    
    func id() throws -> WalletID {
        let builder = Builder()
        try builder.store(self)
        return WalletID(hash: try builder.endCell().representationHash())
    }
  }
}

extension Version_1_0_0.WalletIdentity: Codable {
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

extension Version_1_0_0.WalletIdentity: CellCodable {
  public func storeTo(builder: Builder) throws {
    try network.storeTo(builder: builder)
    try kind.storeTo(builder: builder)
  }
  
  public static func loadFrom(slice: Slice) throws -> Version_1_0_0.WalletIdentity {
    return try slice.tryLoad { s in
      let network: Network = try s.loadType()
      let kind: Version_1_0_0.WalletKind = try s.loadType()
      return Version_1_0_0.WalletIdentity(network: network, kind: kind)
    }
  }
}

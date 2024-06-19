import Foundation
import TonSwift

public extension Wallet {
  struct LedgerDevice: Codable, Equatable, CellCodable {
    public let deviceId: String
    public let deviceModel: String
    public let accountIndex: Int16
    
    public init(deviceId: String,
                deviceModel: String,
                accountIndex: Int16) {
      self.deviceId = deviceId
      self.deviceModel = deviceModel
      self.accountIndex = accountIndex
    }
    
    public func storeTo(builder: TonSwift.Builder) throws {
      let deviceIdData = deviceId.data(using: .utf8) ?? Data()
      try builder.store(uint: deviceIdData.count, bits: .deviceIdCountLength)
      try builder.store(data: deviceIdData)
      let deviceModelData = deviceModel.data(using: .utf8) ?? Data()
      try builder.store(uint: deviceModelData.count, bits: .deviceModelCountLength)
      try builder.store(data: deviceModelData)
      try builder.store(int: accountIndex, bits: .accountIndexLength)
    }
    
    public static func loadFrom(slice: TonSwift.Slice) throws -> Wallet.LedgerDevice {
      return try slice.tryLoad { s in
        let deviceIdCount = Int(try s.loadUint(bits: .deviceIdCountLength))
        let deviceIdData = try s.loadBytes(deviceIdCount)
        guard let deviceId = String(data: deviceIdData, encoding: .utf8) else {
          throw TonError.custom("Invalid deviceId")
        }
        let deviceModelCount = Int(try s.loadUint(bits: .deviceModelCountLength))
        let deviceModelData = try s.loadBytes(deviceModelCount)
        guard let deviceModel = String(data: deviceModelData, encoding: .utf8) else {
          throw TonError.custom("Invalid deviceModel")
        }
        let accountIndex = Int16(try s.loadInt(bits: .accountIndexLength))
        return Wallet.LedgerDevice(
          deviceId: deviceId,
          deviceModel: deviceModel,
          accountIndex: accountIndex
        )
      }
    }
  }
}

private extension Int {
  static let deviceIdCountLength = 10
  static let deviceModelCountLength = 10
  static let accountIndexLength = 16
}

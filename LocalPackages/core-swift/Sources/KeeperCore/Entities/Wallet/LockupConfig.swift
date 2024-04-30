import Foundation
import TonSwift

public struct LockupConfig: Equatable, Codable {
  // TBD: lockup-1.0 config
}

extension LockupConfig: CellCodable {
  public func storeTo(builder: Builder) throws {
    // TBD: Store config
  }
  public static func loadFrom(slice: Slice) throws -> LockupConfig {
    // TBD: Load config
    return LockupConfig()
  }
}

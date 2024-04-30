import Foundation
import CoreComponents

public protocol KeeperInfoRepository {
    func getKeeperInfo() throws -> KeeperInfo
    func saveKeeperInfo(_ keeperInfo: KeeperInfo) throws
    func removeKeeperInfo() throws
}

extension FileSystemVault<KeeperInfo, String>: KeeperInfoRepository {
  public func getKeeperInfo() throws -> KeeperInfo {
    try loadItem(key: String.keeperInfoKey)
  }
  
  public func saveKeeperInfo(_ keeperInfo: KeeperInfo) throws {
    try saveItem(keeperInfo, key: .keeperInfoKey)
  }
  
  public func removeKeeperInfo() throws {
    try deleteItem(key: .keeperInfoKey)
  }
}

private extension String {
  static let keeperInfoKey = "KeeperInfo"
}

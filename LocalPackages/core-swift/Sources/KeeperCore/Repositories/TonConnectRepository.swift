import Foundation
import CoreComponents

protocol TonConnectRepository {
  func getLastEventId() throws -> TonConnectLastEventId
  func saveLastEventId(_ lastEventId: TonConnectLastEventId) throws
}

struct TonConnectRepositoryImplementation: TonConnectRepository {
  let fileSystemVault: FileSystemVault<TonConnectLastEventId, String>
  
  init(fileSystemVault: FileSystemVault<TonConnectLastEventId, String>) {
    self.fileSystemVault = fileSystemVault
  }
  
  func getLastEventId() throws -> TonConnectLastEventId {
    try fileSystemVault.loadItem(key: .lastEventIdKey)
  }
  
  func saveLastEventId(_ lastEventId: TonConnectLastEventId) throws {
    try fileSystemVault.saveItem(lastEventId, key: .lastEventIdKey)
  }
}

private extension String {
  static let lastEventIdKey = "lastEventId"
}

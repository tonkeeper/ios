import Foundation
import TonSwift
import CoreComponents

protocol HistoryRepository {
  func saveEvents(events: AccountEvents, forKey key: String) throws
  func getEvents(forKey key: String) throws -> AccountEvents
}

struct HistoryRepositoryImplementation: HistoryRepository {
  let fileSystemVault: FileSystemVault<AccountEvents, String>
  
  init(fileSystemVault: FileSystemVault<AccountEvents, String>) {
    self.fileSystemVault = fileSystemVault
  }
  
  func saveEvents(events: AccountEvents, forKey key: String) throws {
    try fileSystemVault.saveItem(events, key: key)
  }
  func getEvents(forKey key: String) throws -> AccountEvents {
    try fileSystemVault.loadItem(key: key)
  }
}

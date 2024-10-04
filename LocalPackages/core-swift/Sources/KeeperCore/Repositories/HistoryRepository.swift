import Foundation
import TonSwift
import CoreComponents

protocol HistoryRepository {
  func saveEvents(events: [AccountEvent], forKey key: String) throws
  func getEvents(forKey key: String) throws -> [AccountEvent]
}

struct HistoryRepositoryImplementation: HistoryRepository {
  let fileSystemVault: FileSystemVault<[AccountEvent], String>
  
  init(fileSystemVault: FileSystemVault<[AccountEvent], String>) {
    self.fileSystemVault = fileSystemVault
  }
  
  func saveEvents(events: [AccountEvent], forKey key: String) throws {
    try fileSystemVault.saveItem(events, key: key)
  }
  func getEvents(forKey key: String) throws -> [AccountEvent] {
    try fileSystemVault.loadItem(key: key)
  }
}

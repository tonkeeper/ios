import CoreComponents
import Foundation
import TonSwift

protocol HistoryRepository {
    func saveEvents(events: [HistoryEvent], forKey key: String) throws
    func getEvents(forKey key: String) throws -> [HistoryEvent]
}

struct HistoryRepositoryImplementation: HistoryRepository {
    let fileSystemVault: FileSystemVault<[HistoryEvent], String>

    func saveEvents(events: [HistoryEvent], forKey key: String) throws {
        try fileSystemVault.saveItem(events, key: key)
    }

    func getEvents(forKey key: String) throws -> [HistoryEvent] {
        try fileSystemVault.loadItem(key: key)
    }
}

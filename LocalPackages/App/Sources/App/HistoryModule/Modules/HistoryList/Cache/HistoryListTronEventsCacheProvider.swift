import Foundation
import KeeperCore
import TonSwift

final class HistoryListTronEventsCacheProvider: HistoryListCacheProvider {
    private let historyService: HistoryService

    init(historyService: HistoryService) {
        self.historyService = historyService
    }

    func getCache(wallet: Wallet) throws -> [HistoryEvent] {
        try historyService.cachedEvents(wallet: wallet)
    }

    func setCache(events: [HistoryEvent], wallet: Wallet) throws {
        try historyService.saveEvents(events: events, wallet: wallet)
    }
}

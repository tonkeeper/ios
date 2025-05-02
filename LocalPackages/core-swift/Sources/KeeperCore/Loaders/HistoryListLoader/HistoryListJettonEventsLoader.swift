import Foundation
import TonSwift

final class HistoryListJettonEventsLoader: HistoryListLoader {
  private let jettonInfo: JettonInfo
  private let historyService: HistoryService
  
  init(jettonInfo: JettonInfo,
       historyService: HistoryService) {
    self.jettonInfo = jettonInfo
    self.historyService = historyService
  }

  func loadEvents(wallet: Wallet,
                  pagination: HistoryListLoaderPagination,
                  limit: Int) async throws -> HistoryEventsBatch {
    HistoryEventsBatch(
      accountsEvents: try await historyService.loadEvents(
        wallet: wallet,
        jettonInfo: jettonInfo,
        beforeLt: pagination.tonEventsBeforeLt,
        limit: limit
      ),
      tronTransactions: []
    )
  }
  
  func loadEvent(wallet: Wallet,
                 eventId: String) async throws -> AccountEvent {
    return try await historyService.loadEvent(wallet: wallet, eventId: eventId)
  }
}

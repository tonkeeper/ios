import Foundation
import TonSwift

final class HistoryListAllEventsLoader: HistoryListLoader {
  private let historyService: HistoryService
  private let tonProofTokenService: TonProofTokenService
  private let tronAPI: TronAPI
  
  init(historyService: HistoryService,
       tonProofTokenService: TonProofTokenService,
       tronAPI: TronAPI) {
    self.historyService = historyService
    self.tonProofTokenService = tonProofTokenService
    self.tronAPI = tronAPI
  }
  
  func loadEvents(wallet: Wallet,
                  pagination: HistoryListLoaderPagination,
                  limit: Int) async throws -> HistoryEventsBatch {
    let accountsEvents = try await historyService.loadEvents(
      wallet: wallet,
      beforeLt: pagination.tonEventsBeforeLt,
      limit: limit
    )
    
    let tronEvents = try await loadAllTronEvents(
      events: [],
      wallet: wallet,
      maxTimestamp: pagination.tronEventsMaxTimestamp,
      limit: limit,
      timestampLimit: accountsEvents.events.last?.date.timeIntervalSince1970.int64
    )
    
    return HistoryEventsBatch(
      accountsEvents: accountsEvents,
      tronTransactions: tronEvents
    )
  }
  
  private func loadAllTronEvents(events: [TronTransaction],
                                 wallet: Wallet,
                                 maxTimestamp: Int64?,
                                 limit: Int,
                                 fingerprint: String? = nil,
                                 timestampLimit: Int64?) async throws -> [TronTransaction] {
    guard let address = wallet.tron?.address else {
      return []
    }
    return try await tronAPI.loadAllTronEvents(
      events: events,
      address: address,
      limit: limit,
      tonProofToken: tonProofTokenService.getWalletToken(wallet),
      startTimestamp: maxTimestamp,
      finishTimestamp: timestampLimit
    )
  }

  func loadEvent(wallet: Wallet,
                 eventId: String) async throws -> AccountEvent {
    return try await historyService.loadEvent(wallet: wallet, eventId: eventId)
  }
}

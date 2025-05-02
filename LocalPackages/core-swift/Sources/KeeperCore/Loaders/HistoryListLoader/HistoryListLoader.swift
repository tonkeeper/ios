import Foundation
import TonSwift

struct HistoryListLoaderPagination {
  let tonEventsBeforeLt: Int64?
  let tronEventsMaxTimestamp: Int64?
  let tronHasMore: Bool
  
  var hasMore: Bool {
    tonEventsBeforeLt != 0 || tronHasMore
  }
}

protocol HistoryListLoader {
  func loadEvents(wallet: Wallet,
                  pagination: HistoryListLoaderPagination,
                  limit: Int) async throws -> HistoryEventsBatch
  func loadEvent(wallet: Wallet, eventId: String) async throws -> AccountEvent
}

extension TimeInterval {
  var int64: Int64 {
    Int64(self)
  }
}

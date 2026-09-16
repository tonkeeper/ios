import Foundation
import TonSwift

struct HistoryListLoaderPagination: Sendable {
    let tonEventsBeforeLt: Int64?
    let tronEventsMaxTimestamp: Int64?
    let tonHasMore: Bool
    let tronHasMore: Bool

    var hasMore: Bool {
        tonHasMore || tronHasMore
    }
}

protocol HistoryListLoader {
    func loadEvents(
        wallet: Wallet,
        pagination: HistoryListLoaderPagination,
        limit: Int
    ) async throws -> HistoryEventsBatch
}

extension TimeInterval {
    var int64: Int64 {
        Int64(self)
    }
}

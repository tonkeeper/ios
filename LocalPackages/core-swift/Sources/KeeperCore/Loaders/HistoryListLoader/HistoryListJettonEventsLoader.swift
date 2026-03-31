import Foundation
import TonSwift

final class HistoryListJettonEventsLoader: HistoryListLoader {
    private let jettonMasterAddress: Address
    private let historyService: HistoryService

    init(
        jettonMasterAddress: Address,
        historyService: HistoryService
    ) {
        self.jettonMasterAddress = jettonMasterAddress
        self.historyService = historyService
    }

    func loadEvents(
        wallet: Wallet,
        pagination: HistoryListLoaderPagination,
        limit: Int
    ) async throws -> HistoryEventsBatch {
        try HistoryEventsBatch(
            accountsEvents: await historyService.loadEvents(
                wallet: wallet,
                jettonMasterAddress: jettonMasterAddress,
                beforeLt: pagination.tonEventsBeforeLt,
                limit: limit
            ),
            tronTransactions: []
        )
    }
}

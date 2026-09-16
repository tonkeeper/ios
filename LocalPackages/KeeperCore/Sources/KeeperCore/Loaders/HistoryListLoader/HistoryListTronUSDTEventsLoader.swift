import Foundation

final class HistoryListTronUSDTEventsLoader: HistoryListLoader {
    private let historyService: HistoryService
    private let tronUsdtApi: TronUSDTAPI

    init(
        historyService: HistoryService,
        tronUsdtApi: TronUSDTAPI
    ) {
        self.historyService = historyService
        self.tronUsdtApi = tronUsdtApi
    }

    func loadEvents(
        wallet: Wallet,
        pagination: HistoryListLoaderPagination,
        limit: Int
    ) async throws -> HistoryEventsBatch {
        let exhaustedTon = try AccountEvents(
            address: wallet.address,
            events: [],
            startFrom: 0,
            nextFrom: 0
        )
        guard let addresss = wallet.tron?.address else {
            return HistoryEventsBatch(accountsEvents: exhaustedTon, tronTransactions: [])
        }
        let tronEvents = try await tronUsdtApi.loadAllTronEvents(
            wallet: wallet,
            events: [],
            address: addresss,
            limit: limit,
            startTimestamp: pagination.tronEventsMaxTimestamp,
            finishTimestamp: nil
        )

        return HistoryEventsBatch(
            accountsEvents: exhaustedTon,
            tronTransactions: tronEvents
        )
    }
}

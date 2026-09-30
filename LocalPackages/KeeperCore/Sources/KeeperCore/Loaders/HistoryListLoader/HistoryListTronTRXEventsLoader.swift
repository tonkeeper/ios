import Foundation

final class HistoryListTronTRXEventsLoader: HistoryListLoader {
    private let tronUsdtApi: TronUSDTAPI

    init(tronUsdtApi: TronUSDTAPI) {
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
        guard let address = wallet.tron?.address else {
            return HistoryEventsBatch(accountsEvents: exhaustedTon, tronTransactions: [])
        }
        let transfers = try await tronUsdtApi.loadTRXTransfers(
            address: address,
            limit: limit,
            startTimestamp: pagination.tronEventsMaxTimestamp
        )
        return HistoryEventsBatch(accountsEvents: exhaustedTon, tronTransactions: transfers)
    }
}

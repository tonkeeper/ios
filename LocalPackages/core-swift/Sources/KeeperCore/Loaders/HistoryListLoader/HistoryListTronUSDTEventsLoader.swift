import Foundation

final class HistoryListTronUSDTEventsLoader: HistoryListLoader {
    private let historyService: HistoryService
    private let tonProofTokenService: TonProofTokenService
    private let tronUsdtApi: TronUSDTAPI

    init(
        historyService: HistoryService,
        tonProofTokenService: TonProofTokenService,
        tronUsdtApi: TronUSDTAPI
    ) {
        self.historyService = historyService
        self.tonProofTokenService = tonProofTokenService
        self.tronUsdtApi = tronUsdtApi
    }

    func loadEvents(
        wallet: Wallet,
        pagination: HistoryListLoaderPagination,
        limit: Int
    ) async throws -> HistoryEventsBatch {
        guard let addresss = wallet.tron?.address else {
            return HistoryEventsBatch(accountsEvents: nil, tronTransactions: [])
        }
        let tronEvents = try await tronUsdtApi.loadAllTronEvents(
            events: [],
            address: addresss,
            limit: limit,
            tonProofToken: tonProofTokenService.getWalletToken(wallet),
            startTimestamp: pagination.tronEventsMaxTimestamp,
            finishTimestamp: nil
        )

        return HistoryEventsBatch(
            accountsEvents: nil,
            tronTransactions: tronEvents
        )
    }
}

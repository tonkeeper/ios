import Foundation

final class HistoryListTronUSDTEventsLoader: HistoryListLoader {
    private let historyService: HistoryService
    private let tonProofTokenService: TonProofTokenService
    private let tronAPI: TronAPI

    init(
        historyService: HistoryService,
        tonProofTokenService: TonProofTokenService,
        tronAPI: TronAPI
    ) {
        self.historyService = historyService
        self.tonProofTokenService = tonProofTokenService
        self.tronAPI = tronAPI
    }

    func loadEvents(
        wallet: Wallet,
        pagination: HistoryListLoaderPagination,
        limit: Int
    ) async throws -> HistoryEventsBatch {
        guard let addresss = wallet.tron?.address else {
            return HistoryEventsBatch(accountsEvents: nil, tronTransactions: [])
        }
        let tronEvents = try await tronAPI.loadAllTronEvents(
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

    func loadEvent(
        wallet: Wallet,
        eventId: String
    ) async throws -> AccountEvent {
        return try await historyService.loadEvent(wallet: wallet, eventId: eventId)
    }
}

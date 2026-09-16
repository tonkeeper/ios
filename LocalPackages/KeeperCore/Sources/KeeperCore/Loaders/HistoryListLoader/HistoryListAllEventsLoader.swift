import Foundation
import TonSwift

final class HistoryListAllEventsLoader: HistoryListLoader {
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
        let accountsResult = await loadAccountsEvents(
            wallet: wallet,
            beforeLt: pagination.tonEventsBeforeLt,
            limit: limit,
            hasMore: pagination.tonHasMore
        )

        try Task.checkCancellation()

        let accountsEvents = try? accountsResult.get()
        let timestampLimit = accountsEvents?.events.last?.date.timeIntervalSince1970.int64

        let tronResult = await loadTronEvents(
            wallet: wallet,
            maxTimestamp: pagination.tronEventsMaxTimestamp,
            limit: limit,
            hasMore: pagination.tronHasMore,
            finishTimestamp: timestampLimit
        )

        try Task.checkCancellation()

        let tronTransactions = try? tronResult.get()

        let hasAccountsEvents = !(accountsEvents?.events.isEmpty ?? true)
        let hasTronTransactions = !(tronTransactions?.isEmpty ?? true)

        if !hasAccountsEvents && !hasTronTransactions {
            if case let .failure(error) = accountsResult {
                throw error
            }
            if case let .failure(error) = tronResult {
                throw error
            }
        }

        return HistoryEventsBatch(
            accountsEvents: accountsEvents,
            tronTransactions: tronTransactions
        )
    }

    private func loadAccountsEvents(
        wallet: Wallet,
        beforeLt: Int64?,
        limit: Int,
        hasMore: Bool
    ) async -> Result<AccountEvents, Error> {
        guard hasMore else {
            do {
                let exhausted = try AccountEvents(
                    address: wallet.address,
                    events: [],
                    startFrom: 0,
                    nextFrom: 0
                )
                return .success(exhausted)
            } catch {
                return .failure(error)
            }
        }
        do {
            let events = try await historyService.loadEvents(
                wallet: wallet,
                beforeLt: beforeLt,
                limit: limit
            )
            return .success(events)
        } catch {
            return .failure(error)
        }
    }

    private func loadTronEvents(
        wallet: Wallet,
        maxTimestamp: Int64?,
        limit: Int,
        hasMore: Bool,
        finishTimestamp: Int64?
    ) async -> Result<[TronTransaction], Error> {
        guard hasMore else {
            return .success([])
        }
        guard let address = wallet.tron?.address else {
            return .success([])
        }
        do {
            let events = try await tronUsdtApi.loadAllTronEvents(
                wallet: wallet,
                events: [],
                address: address,
                limit: limit,
                startTimestamp: maxTimestamp,
                finishTimestamp: finishTimestamp
            )
            return .success(events)
        } catch {
            return .failure(error)
        }
    }
}

import Foundation
import TonSwift

final class HistoryListTonEventsLoader: HistoryListLoader {
    private let historyService: HistoryService

    init(historyService: HistoryService) {
        self.historyService = historyService
    }

    func loadEvents(
        wallet: Wallet,
        pagination: HistoryListLoaderPagination,
        limit: Int
    ) async throws -> HistoryEventsBatch {
        let loadedEvents = try await historyService.loadEvents(
            wallet: wallet,
            beforeLt: pagination.tonEventsBeforeLt,
            limit: limit
        )

        let filteredEvents = loadedEvents.events.compactMap { event -> AccountEvent? in
            let filteredActions = event.actions.compactMap { action -> AccountEventAction? in
                guard case .tonTransfer = action.type else { return nil }
                return action
            }
            guard !filteredActions.isEmpty else { return nil }
            return AccountEvent(
                eventId: event.eventId,
                date: event.date,
                account: event.account,
                isScam: event.isScam,
                isInProgress: event.isInProgress,
                extra: event.extra,
                excess: event.excess,
                progress: event.progress,
                actions: filteredActions
            )
        }

        return try HistoryEventsBatch(
            accountsEvents: AccountEvents(
                address: wallet.address,
                events: filteredEvents,
                startFrom: loadedEvents.startFrom,
                nextFrom: loadedEvents.nextFrom
            ),
            tronTransactions: []
        )
    }
}

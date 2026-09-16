import Foundation
import TKFeatureFlags

/// Fetches wallet-scoped raffles and feeds `RaffleStore`.
public actor RaffleLoader {
    typealias LoadRaffles = (
        _ walletId: String,
        _ lang: String?,
        _ ids: [String]?,
        _ debugNow: Date?,
        _ isNewUser: Bool
    ) async throws -> [MultichainRaffle]

    private struct Request: Equatable {
        let walletId: String
        let lang: String?
        let ids: [String]?
        let debugNow: Date?
        let isNewUser: Bool
    }

    private var taskInProgress: Task<Void, Never>?
    private var taskInProgressID: UUID?
    private var taskInProgressRequest: Request?
    private var currentWalletId: String?
    private var latestEnqueuedOperationID: UInt64 = 0

    private let loadRaffles: LoadRaffles
    private let raffleStore: RaffleStore
    private let appSettings: TKAppSettings
    private nonisolated let operationSequence = RaffleLoaderOperationSequence()

    init(
        multichainService: MultichainService,
        raffleStore: RaffleStore,
        appSettings: TKAppSettings
    ) {
        self.loadRaffles = { walletId, lang, ids, debugNow, isNewUser in
            try await multichainService.getWalletRaffles(
                walletId: walletId,
                lang: lang,
                ids: ids,
                debugNow: debugNow,
                isNewUser: isNewUser
            )
        }
        self.raffleStore = raffleStore
        self.appSettings = appSettings
    }

    init(
        loadRaffles: @escaping LoadRaffles,
        raffleStore: RaffleStore,
        appSettings: TKAppSettings
    ) {
        self.loadRaffles = loadRaffles
        self.raffleStore = raffleStore
        self.appSettings = appSettings
    }

    public nonisolated func loadRaffles(walletId: String, lang: String?, ids: [String]?) {
        let operationID = operationSequence.next()
        Task {
            await loadRafflesNow(walletId: walletId, lang: lang, ids: ids, operationID: operationID)
        }
    }

    public nonisolated func clearRaffles() {
        let operationID = operationSequence.next()
        Task {
            await clearRafflesState(operationID: operationID)
        }
    }

    func loadRafflesNow(
        walletId: String,
        lang: String?,
        ids: [String]?,
        operationID: UInt64? = nil
    ) async {
        guard acceptEnqueuedOperation(operationID) else { return }
        let request = Request(
            walletId: walletId,
            lang: lang,
            ids: ids,
            debugNow: appSettings.raffleDebugNow,
            isNewUser: appSettings.raffleIsNewUser ?? false
        )

        if taskInProgress != nil, taskInProgressRequest == request {
            return
        }

        if let taskInProgress {
            taskInProgress.cancel()
            self.taskInProgress = nil
            self.taskInProgressID = nil
            self.taskInProgressRequest = nil
        }

        if currentWalletId != walletId {
            // Switching wallets: drop the previous wallet's raffles immediately so a
            // failed fetch below can't leave them displayed under the new wallet.
            currentWalletId = walletId
            await raffleStore.setRaffles([])
        }

        let taskID = UUID()
        let task = Task { [loadRaffles] in
            let raffles: [MultichainRaffle]
            do {
                raffles = try await loadRaffles(
                    request.walletId,
                    request.lang,
                    request.ids,
                    request.debugNow,
                    request.isNewUser
                )
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await raffleStore.setRaffles(raffles)
        }
        self.taskInProgress = task
        self.taskInProgressID = taskID
        self.taskInProgressRequest = request
        await task.value
        clearTaskInProgress(id: taskID)
    }

    private func clearRafflesState(operationID: UInt64? = nil) async {
        guard acceptEnqueuedOperation(operationID) else { return }
        if let taskInProgress {
            taskInProgress.cancel()
            self.taskInProgress = nil
            self.taskInProgressID = nil
            self.taskInProgressRequest = nil
        }
        currentWalletId = nil
        await raffleStore.setRaffles([])
    }

    private func acceptEnqueuedOperation(_ operationID: UInt64?) -> Bool {
        guard let operationID else { return true }
        guard operationID > latestEnqueuedOperationID else { return false }
        latestEnqueuedOperationID = operationID
        return true
    }

    private func clearTaskInProgress(id: UUID) {
        guard taskInProgressID == id else { return }
        taskInProgress = nil
        taskInProgressID = nil
        taskInProgressRequest = nil
    }
}

private final class RaffleLoaderOperationSequence: @unchecked Sendable {
    private let lock = NSLock()
    private var value: UInt64 = 0

    func next() -> UInt64 {
        lock.withLock {
            value &+= 1
            return value
        }
    }
}

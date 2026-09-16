import Foundation

struct WalletConnectSessionReconciler {
    private let repository: WalletConnectSessionRepository

    init(repository: WalletConnectSessionRepository) {
        self.repository = repository
    }

    @WalletConnectActor
    func reconcile(
        sdkSessions: [WalletConnectSession]
    ) -> WalletConnectSessionsReconciliation {
        let storedSessions = repository.storedSessions()
        let sdkTopics = Set(sdkSessions.map(\.topic))
        let staleTopics = storedSessions.keys
            .filter { !sdkTopics.contains($0) }
            .sorted()

        let storageError: WalletConnectSessionStoreError?
        do {
            try repository.removeSessions(
                topics: staleTopics,
                context: "active sessions reconciliation"
            )
            storageError = nil
        } catch {
            storageError = error
        }

        let enrichedSessions = repository.enrichSessions(sdkSessions)
        let orphanTopics = enrichedSessions
            .filter { $0.walletId == nil }
            .map(\.topic)
            .sorted()

        return WalletConnectSessionsReconciliation(
            sessions: enrichedSessions,
            orphanTopics: orphanTopics,
            staleTopics: staleTopics,
            storageError: storageError
        )
    }
}

struct WalletConnectSessionsReconciliation: Equatable {
    let sessions: [WalletConnectSession]
    let orphanTopics: [String]
    let staleTopics: [String]
    let storageError: WalletConnectSessionStoreError?
}

struct WalletConnectSessionContext: Equatable {
    let dapp: WalletConnectDapp
    let walletId: String
    let sourceState: DappConnectionSourceState
}

enum WalletConnectSessionContextLookup: Equatable {
    case found(WalletConnectSessionContext)
    case missingDapp
    case missingWalletMapping
}

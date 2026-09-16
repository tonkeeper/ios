import Foundation
import TKLogging

@WalletConnectActor
final class WalletConnectSessionRepository: Sendable {
    private let store: WalletConnectSessionStore
    private let now: @Sendable () -> Date
    private var sessions: [String: WalletConnectStoredSession]

    init(
        store: WalletConnectSessionStore,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.store = store
        self.now = now
        self.sessions = store.load()
    }
}

extension WalletConnectSessionRepository {
    func recordApprovedSession(
        _ session: WalletConnectSession,
        proposal: WalletConnectSessionProposal,
        walletId: String
    ) throws(WalletConnectSessionStoreError) {
        var updatedSessions = sessions
        updatedSessions[session.topic] = WalletConnectStoredSession(
            walletId: walletId,
            source: proposal.source,
            createdAt: now()
        )
        try saveSessions(
            updatedSessions,
            context: "session approved"
        )
    }

    func removeSession(
        topic: String,
        context: String
    ) throws(WalletConnectSessionStoreError) {
        try removeSessions(topics: [topic], context: context)
    }

    func removeSessions(
        topics: [String],
        context: String
    ) throws(WalletConnectSessionStoreError) {
        let existingTopics = topics.filter { sessions[$0] != nil }
        guard !existingTopics.isEmpty else {
            return
        }

        var updatedSessions = sessions
        for topic in existingTopics {
            updatedSessions.removeValue(forKey: topic)
        }
        try saveSessions(
            updatedSessions,
            context: "\(context), removedSessionCount=\(existingTopics.count)"
        )
    }

    func storedSessions() -> [String: WalletConnectStoredSession] {
        sessions
    }

    func storedSession(topic: String) -> WalletConnectStoredSession? {
        sessions[topic]
    }

    func enrichSession(_ session: WalletConnectSession) -> WalletConnectSession {
        let stored = sessions[session.topic]
        return WalletConnectSession(
            topic: session.topic,
            dapp: session.dapp,
            walletId: stored?.walletId,
            sourceState: stored?.sourceState ?? .unknown,
            chains: session.chains
        )
    }

    func enrichSessions(_ sessions: [WalletConnectSession]) -> [WalletConnectSession] {
        sessions.map(enrichSession)
    }
}

private extension WalletConnectSessionRepository {
    func saveSessions(
        _ updatedSessions: [String: WalletConnectStoredSession],
        context: String
    ) throws(WalletConnectSessionStoreError) {
        do {
            try store.save(updatedSessions)
            sessions = updatedSessions
        } catch {
            logWalletConnectSessionStorageFailure(context: context, error: error)
            throw error
        }
    }
}

private func logWalletConnectSessionStorageFailure(
    context: String,
    error: Error
) {
    Log.e("WalletConnect: failed to save sessions after \(context)", error: error)
}

import Foundation
import TKLogging

@WalletConnectActor
final class WalletConnectPairingCoordinator: Sendable {
    private let eventSink: MulticastAsyncStream<WalletConnectServiceEvent>
    private let sourceStore: WalletConnectPairingSourceStore
    private let pairingProposalTimeoutNanoseconds: UInt64
    private let activePairingSourceLifetime: TimeInterval
    private let now: @Sendable () -> Date

    private var sourceByPairingTopic = [String: WalletConnectStoredPairingSource]()
    private var pendingPairings = [String: WalletConnectPendingPairing]()
    private var pairingTimeoutTasks = [String: Task<Void, Never>]()

    init(
        eventSink: MulticastAsyncStream<WalletConnectServiceEvent>,
        sourceStore: WalletConnectPairingSourceStore,
        pairingProposalTimeoutNanoseconds: UInt64,
        activePairingSourceLifetime: TimeInterval = 30 * 24 * 60 * 60,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.eventSink = eventSink
        self.sourceStore = sourceStore
        self.pairingProposalTimeoutNanoseconds = pairingProposalTimeoutNanoseconds
        self.activePairingSourceLifetime = activePairingSourceLifetime
        self.now = now

        let storedSources = sourceStore.load()
        self.sourceByPairingTopic = activeSources(
            storedSources,
            now: now()
        )
        if sourceByPairingTopic.count != storedSources.count {
            persistPairingSources(
                sourceByPairingTopic,
                sourceStore: sourceStore,
                context: "expired pairing sources cleanup"
            )
        }
    }

    deinit {
        pairingTimeoutTasks.values.forEach { $0.cancel() }
    }
}

extension WalletConnectPairingCoordinator {
    func preparePairing(
        uri: String,
        source: DappConnectionSource
    ) throws(WalletConnectPairingError) -> WalletConnectPreparedPairing {
        let pairingTopic = try WalletConnectURIParser.requiredPairingTopic(from: uri)
        if let pendingPairing = pendingPairings[pairingTopic] {
            return WalletConnectPreparedPairing(
                pairingTopic: pairingTopic,
                source: pendingPairing.source,
                isDuplicate: true
            )
        }

        let expiresAt = pairingSourceExpirationDate(uri: uri)
        sourceByPairingTopic[pairingTopic] = WalletConnectStoredPairingSource(
            source: source,
            expiresAt: expiresAt
        )
        pendingPairings[pairingTopic] = WalletConnectPendingPairing(source: source)
        persistSources(context: "pairing prepared")
        return WalletConnectPreparedPairing(
            pairingTopic: pairingTopic,
            source: source,
            isDuplicate: false
        )
    }

    func startPairing(pairingTopic: String) {
        guard let pairing = pendingPairings[pairingTopic] else {
            return
        }
        schedulePairingTimeout(pairingTopic: pairingTopic)
        eventSink.emit(.pairingStarted(pairingTopic: pairingTopic, source: pairing.source))
        logPairingStarted(pairingTopic: pairingTopic, source: pairing.source)
    }

    func cancelPairing(
        pairingTopic: String,
        removeSource: Bool
    ) {
        completePairing(pairingTopic: pairingTopic)
        if removeSource {
            sourceByPairingTopic.removeValue(forKey: pairingTopic)
            persistSources(context: "pairing cancelled")
        }
    }

    func source(
        pairingTopic: String,
        fallback: DappConnectionSource
    ) -> DappConnectionSource {
        removeExpiredSources()
        return sourceByPairingTopic[pairingTopic]?.source ?? fallback
    }

    func completePendingPairing(pairingTopic: String) {
        completePairing(pairingTopic: pairingTopic)
    }

    func markPairingActive(pairingTopic: String) {
        guard var storedSource = sourceByPairingTopic[pairingTopic] else {
            return
        }
        let expiresAt = now().addingTimeInterval(activePairingSourceLifetime)
        guard expiresAt > storedSource.expiresAt else {
            return
        }
        storedSource.expiresAt = expiresAt
        sourceByPairingTopic[pairingTopic] = storedSource
        persistSources(context: "pairing activated")
    }
}

private extension WalletConnectPairingCoordinator {
    func schedulePairingTimeout(pairingTopic: String) {
        pairingTimeoutTasks[pairingTopic]?.cancel()
        let timeout = pairingProposalTimeoutNanoseconds
        pairingTimeoutTasks[pairingTopic] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: timeout)
            guard !Task.isCancelled else {
                return
            }
            self?.expirePairing(pairingTopic: pairingTopic)
        }
    }

    func completePairing(pairingTopic: String) {
        pendingPairings.removeValue(forKey: pairingTopic)
        pairingTimeoutTasks.removeValue(forKey: pairingTopic)?.cancel()
    }

    func expirePairing(pairingTopic: String) {
        guard let pairing = pendingPairings.removeValue(forKey: pairingTopic) else {
            return
        }
        pairingTimeoutTasks.removeValue(forKey: pairingTopic)?.cancel()
        sourceByPairingTopic.removeValue(forKey: pairingTopic)
        persistSources(context: "pairing expired")
        eventSink.emit(.pairingExpired(pairingTopic: pairingTopic, source: pairing.source))
        logPairingExpired(source: pairing.source)
    }

    func removeExpiredSources() {
        let activeSources = activeSources(
            sourceByPairingTopic,
            now: now()
        )
        guard activeSources.count != sourceByPairingTopic.count else {
            return
        }
        sourceByPairingTopic = activeSources
        persistSources(context: "expired pairing sources cleanup")
    }

    func persistSources(context: String) {
        persistPairingSources(
            sourceByPairingTopic,
            sourceStore: sourceStore,
            context: context
        )
    }

    func pairingSourceExpirationDate(uri: String) -> Date {
        let timeoutExpiration = now()
            .addingTimeInterval(TimeInterval(pairingProposalTimeoutNanoseconds) / 1_000_000_000)
        guard let uriExpiration = WalletConnectURIParser.pairingExpirationDate(from: uri) else {
            return timeoutExpiration
        }
        return min(uriExpiration, timeoutExpiration)
    }
}

struct WalletConnectPreparedPairing: Equatable {
    let pairingTopic: String
    let source: DappConnectionSource
    let isDuplicate: Bool
}

enum WalletConnectPairingTimeouts {
    static let defaultProposalNanoseconds: UInt64 = 300_000_000_000
}

private struct WalletConnectPendingPairing {
    let source: DappConnectionSource
}

private func activeSources(
    _ sources: [String: WalletConnectStoredPairingSource],
    now: Date
) -> [String: WalletConnectStoredPairingSource] {
    sources.filter { $0.value.expiresAt > now }
}

private func persistPairingSources(
    _ sources: [String: WalletConnectStoredPairingSource],
    sourceStore: WalletConnectPairingSourceStore,
    context: String
) {
    do {
        try sourceStore.save(sources)
    } catch {
        logPairingSourceStorageFailure(context: context, error: error)
    }
}

private func logPairingStarted(pairingTopic _: String, source: DappConnectionSource) {
    Log.walletConnect.i("pairing started", extraInfo: [
        "source": "\(source)",
    ])
}

private func logPairingSourceStorageFailure(context: String, error: Error) {
    Log.e("WalletConnect: failed to save pairing source after \(context)", error: error)
}

private func logPairingExpired(source: DappConnectionSource) {
    Log.walletConnect.i("pairing expired", extraInfo: [
        "source": "\(source)",
    ])
}

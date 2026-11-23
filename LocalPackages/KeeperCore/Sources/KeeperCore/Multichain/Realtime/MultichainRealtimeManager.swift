import Foundation
import TKLogging

private let supportedEnvelopeVersion = 1
/// A shorter outage is unlikely to have missed events. The backend can re-establish a subscription every few
/// seconds, and a resync on each would reload every wallet surface (Android: `RESYNC_MIN_GAP`).
private let resyncMinimumGap: TimeInterval = 15

public final class MultichainRealtimeManager {
    private let walletsStore: WalletsStore
    private let endpointProvider: () -> URL
    private let transport: MultichainRealtimeTransport
    private let uptime: () -> TimeInterval

    private let subscriptionObservers = LockedObserverStore<String?>()

    private let syncQueue: DispatchQueue
    private let subscriptionLock = NSLock()
    private let walletHints: MultichainWalletHints
    private let perps: PerpsRealtimeChannel
    private let eventHandlers: [MultichainRealtimeEventHandler]
    private var isForeground = false
    private var isDisabledByBackend = false
    private var didStart = false
    private var connectedWalletId: String?
    private var connectedEndpoint: URL?
    private var connectionID = UUID()
    private var subscribedWalletId: String?
    private var unsubscribedAt = [String: TimeInterval]()

    init(
        walletsStore: WalletsStore,
        transport: MultichainRealtimeTransport,
        endpointProvider: @escaping () -> URL,
        uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) {
        self.walletsStore = walletsStore
        self.transport = transport
        self.endpointProvider = endpointProvider
        self.uptime = uptime
        let syncQueue = DispatchQueue(label: "com.tonkeeper.multichain.realtime.manager")
        let walletHints = MultichainWalletHints()
        let perps = PerpsRealtimeChannel(queue: syncQueue, transport: transport)
        self.syncQueue = syncQueue
        self.walletHints = walletHints
        self.perps = perps
        eventHandlers = [walletHints, perps]
    }

    /// Delivery is not bound to an executor; observers enter their own isolation domain.
    public func addBalanceChangeObserver<T: AnyObject>(
        _ observer: T,
        closure: @escaping (T, String) -> Void
    ) {
        walletHints.addBalanceChangeObserver(observer, closure: closure)
    }

    /// Delivery is not bound to an executor; observers enter their own isolation domain.
    public func addHistoryInvalidationObserver<T: AnyObject>(
        _ observer: T,
        closure: @escaping (T, String) -> Void
    ) {
        walletHints.addHistoryInvalidationObserver(observer, closure: closure)
    }

    public func addSubscriptionObserver<T: AnyObject>(
        _ observer: T,
        closure: @escaping (T, String?) -> Void
    ) {
        subscriptionObservers.add(observer) { observer, walletId in
            closure(observer, walletId)
        }
    }

    func perpsSignals(walletId: String) -> AsyncStream<PerpsRealtimeSignal> {
        perps.signals(walletId: walletId)
    }

    public func isSubscribed(walletId: String) -> Bool {
        subscriptionLock.lock()
        defer { subscriptionLock.unlock() }
        return subscribedWalletId == walletId
    }

    public func start() {
        syncQueue.async { [weak self] in
            guard let self, !self.didStart else { return }
            self.didStart = true

            self.walletsStore.addObserver(self) { observer, event in
                switch event {
                case .didChangeActiveWallet, .didUpdateWalletMultichain, .didDeleteWallet, .didDeleteAll:
                    observer.syncQueue.async {
                        observer.reconcileConnection()
                    }
                default:
                    break
                }
            }
            self.reconcileConnection()
        }
    }

    public func setForeground(_ foreground: Bool) {
        syncQueue.async { [weak self] in
            guard let self else { return }
            self.isForeground = foreground
            self.reconcileConnection()
        }
    }

    func configurationDidChange() {
        syncQueue.async { [weak self] in
            self?.reconcileConnection()
        }
    }

    func handleSignalForTesting(_ signal: MultichainRealtimeSignal) {
        syncQueue.async { [weak self] in
            self?.handleSignal(signal)
        }
    }

    private func markDisabledByBackend(connectionID: UUID) {
        syncQueue.async { [weak self] in
            guard let self else { return }
            guard self.connectionID == connectionID else { return }
            self.isDisabledByBackend = true
            self.reconcileConnection()
        }
    }

    private func reconcileConnection() {
        let walletId = desiredWalletId()
        let endpoint = walletId.map { _ in endpointProvider() }
        guard walletId != connectedWalletId || endpoint != connectedEndpoint else { return }
        Log.multichain.i(
            "Realtime target: \(walletId.map { "wallet:\(walletLogId($0))" } ?? "none") foreground:\(isForeground) disabledByBackend:\(isDisabledByBackend)"
        )
        if connectedWalletId != nil {
            transport.disconnect()
        }
        connectionID = UUID()
        connectedWalletId = walletId
        connectedEndpoint = endpoint
        setSubscribedWalletId(nil)
        perps.connectionChanged(walletId: walletId)
        walletHints.cancelPending()

        if let walletId, let endpoint {
            let connectionID = self.connectionID
            transport.setSignalHandler { [weak self] signal in
                guard let self else { return }
                self.syncQueue.async {
                    guard self.connectionID == connectionID else { return }
                    self.handleSignal(signal)
                }
            }
            transport.setDisabledByBackendHandler { [weak self] in
                self?.markDisabledByBackend(connectionID: connectionID)
            }
            transport.connect(walletId: walletId, endpoint: endpoint)
        }
    }

    private func desiredWalletId() -> String? {
        guard isForeground,
              !isDisabledByBackend,
              let wallet = try? walletsStore.activeWallet,
              let walletId = wallet.multichainWalletState?.walletId
        else {
            return nil
        }
        return walletId
    }

    private func handleSignal(_ signal: MultichainRealtimeSignal) {
        switch signal {
        case let .subscribed(walletId, resubscribed):
            setSubscribedWalletId(walletId)
            if resubscribed, missedEventsLikely(walletId: walletId) {
                resync(walletId: walletId)
            }
        case let .unsubscribed(walletId):
            if isSubscribed(walletId: walletId) {
                unsubscribedAt[walletId] = uptime()
                setSubscribedWalletId(nil)
            }
        case let .publication(walletId, payload):
            handlePublication(walletId: walletId, payload: payload)
        case let .perpsSubscribed(walletId, recovered):
            perps.subscribed(walletId: walletId, recovered: recovered)
        case let .perpsUnsubscribed(walletId):
            perps.unsubscribed(walletId: walletId)
        }
    }

    private func setSubscribedWalletId(_ walletId: String?) {
        subscriptionLock.lock()
        let previous = subscribedWalletId
        subscribedWalletId = walletId
        subscriptionLock.unlock()
        guard previous != walletId else { return }
        subscriptionObservers.notify(walletId)
    }

    private func missedEventsLikely(walletId: String) -> Bool {
        guard let since = unsubscribedAt[walletId] else { return true }
        return uptime() - since >= resyncMinimumGap
    }

    private func resync(walletId: String) {
        Log.multichain.i("Realtime resync after reconnect: wallet:\(walletLogId(walletId))")
        walletHints.resync(walletId: walletId)
    }

    private func handlePublication(walletId: String, payload: Data) {
        guard let envelope = parseEnvelope(payload) else { return }
        guard envelope.version == supportedEnvelopeVersion,
              envelope.walletId == walletId
        else {
            Log.multichain.w(
                "Realtime event dropped: v=\(envelope.version) event=\(envelope.event) wallet=\(walletLogId(envelope.walletId)) expected=\(walletLogId(walletId)) seq=\(envelope.seq)"
            )
            return
        }

        Log.multichain.i(
            "Realtime event: \(envelope.event) wallet:\(walletLogId(envelope.walletId)) seq:\(envelope.seq)"
        )

        for handler in eventHandlers where handler.accept(envelope, payload: payload) {
            return
        }
        Log.multichain.i("Realtime event ignored: \(envelope.event)")
    }

    private func parseEnvelope(_ payload: Data) -> MultichainRealtimeEnvelope? {
        do {
            return try JSONDecoder().decode(MultichainRealtimeEnvelope.self, from: payload)
        } catch {
            Log.multichain.w("Realtime envelope is malformed", error: error)
            return nil
        }
    }
}

import Foundation
import TKLogging

private let supportedEnvelopeVersion = 1
private let eventBalanceHint = "balance.hint"
private let eventActivityHint = "activity.hint"
private let hintDebounceNanoseconds: UInt64 = 400_000_000

struct MultichainRealtimeEnvelope: Decodable, Equatable {
    let version: Int
    let event: String
    let walletId: String
    let seq: Int64

    enum CodingKeys: String, CodingKey {
        case version = "v"
        case event
        case walletId = "wallet_id"
        case seq
    }
}

public final class MultichainRealtimeManager {
    private let walletsStore: WalletsStore
    private let endpointProvider: () -> URL
    private let transport: MultichainRealtimeTransport

    private let balanceChangeObservers = LockedObserverStore<String>()
    private let historyInvalidationObservers = LockedObserverStore<String>()
    private let subscriptionObservers = LockedObserverStore<String?>()

    private let syncQueue = DispatchQueue(label: "com.tonkeeper.multichain.realtime.manager")
    private let subscriptionLock = NSLock()
    private var appliedSeq = [String: Int64]()
    private var isForeground = false
    private var isDisabledByBackend = false
    private var didStart = false
    private var balanceHintTask: Task<Void, Never>?
    private var activityHintTask: Task<Void, Never>?
    private var connectedWalletId: String?
    private var connectedEndpoint: URL?
    private var connectionID = UUID()
    private var subscribedWalletId: String?

    init(
        walletsStore: WalletsStore,
        transport: MultichainRealtimeTransport,
        endpointProvider: @escaping () -> URL
    ) {
        self.walletsStore = walletsStore
        self.transport = transport
        self.endpointProvider = endpointProvider
    }

    /// Delivery is not bound to an executor; observers enter their own isolation domain.
    public func addBalanceChangeObserver<T: AnyObject>(
        _ observer: T,
        closure: @escaping (T, String) -> Void
    ) {
        balanceChangeObservers.add(observer) { observer, walletId in
            closure(observer, walletId)
        }
    }

    /// Delivery is not bound to an executor; observers enter their own isolation domain.
    public func addHistoryInvalidationObserver<T: AnyObject>(
        _ observer: T,
        closure: @escaping (T, String) -> Void
    ) {
        historyInvalidationObservers.add(observer) { observer, walletId in
            closure(observer, walletId)
        }
    }

    public func addSubscriptionObserver<T: AnyObject>(
        _ observer: T,
        closure: @escaping (T, String?) -> Void
    ) {
        subscriptionObservers.add(observer) { observer, walletId in
            closure(observer, walletId)
        }
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
        if connectedWalletId != nil {
            transport.disconnect()
        }
        connectionID = UUID()
        connectedWalletId = walletId
        connectedEndpoint = endpoint
        setSubscribedWalletId(nil)
        balanceHintTask?.cancel()
        activityHintTask?.cancel()

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
            if resubscribed {
                resync(walletId: walletId)
            }
        case let .unsubscribed(walletId):
            if isSubscribed(walletId: walletId) {
                setSubscribedWalletId(nil)
            }
        case let .publication(walletId, payload):
            handlePublication(walletId: walletId, payload: payload)
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

    private func resync(walletId: String) {
        Log.multichain.d("Realtime resync after reconnect: \(walletId)")
        scheduleBalanceHint(walletId: walletId)
        scheduleActivityHint(walletId: walletId)
    }

    private func handlePublication(walletId: String, payload: Data) {
        guard let envelope = parseEnvelope(payload) else { return }
        guard envelope.version == supportedEnvelopeVersion,
              envelope.walletId == walletId
        else {
            Log.multichain.d(
                "Realtime event dropped: v=\(envelope.version) event=\(envelope.event) wallet=\(envelope.walletId) expected=\(walletId) seq=\(envelope.seq)"
            )
            return
        }

        Log.multichain.d(
            "Realtime event: \(envelope.event) wallet:\(envelope.walletId) seq:\(envelope.seq)"
        )

        switch envelope.event {
        case eventBalanceHint:
            guard markApplied(envelope) else { return }
            scheduleBalanceHint(walletId: envelope.walletId)
        case eventActivityHint:
            guard markApplied(envelope) else { return }
            scheduleActivityHint(walletId: envelope.walletId)
        default:
            Log.multichain.d("Realtime event ignored: \(envelope.event)")
        }
    }

    private func scheduleBalanceHint(walletId: String) {
        balanceHintTask?.cancel()
        balanceHintTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: hintDebounceNanoseconds)
            guard !Task.isCancelled else { return }
            self?.balanceChangeObservers.notify(walletId)
        }
    }

    private func scheduleActivityHint(walletId: String) {
        activityHintTask?.cancel()
        activityHintTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: hintDebounceNanoseconds)
            guard !Task.isCancelled else { return }
            self?.historyInvalidationObservers.notify(walletId)
        }
    }

    private func markApplied(_ envelope: MultichainRealtimeEnvelope) -> Bool {
        let key = "\(envelope.walletId):\(envelope.event)"
        if let previous = appliedSeq[key], envelope.seq <= previous {
            return false
        }
        appliedSeq[key] = envelope.seq
        return true
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

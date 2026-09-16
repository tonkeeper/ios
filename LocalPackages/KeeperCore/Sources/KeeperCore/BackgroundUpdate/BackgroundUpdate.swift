import Foundation
import OpenAPIRuntime
import TonAPI

/// Synchronous façade over `BackgroundUpdateRuntime`. `start()`/`stop()` only order a command, so
/// no teardown ever runs on the caller's thread — which is what the background transition needs.
public final class BackgroundUpdate {
    private let eventObservers: LockedObserverStore<(wallet: Wallet, event: BackgroundUpdateEvent)>
    private let stateSnapshot: BackgroundUpdateStateSnapshot

    private let walletStore: WalletsStore
    private let commandContinuation: AsyncStream<BackgroundUpdateCommand>.Continuation
    private let commandWorker: Task<Void, Never>
    private let eventWorker: Task<Void, Never>

    init(
        walletStore: WalletsStore,
        walletBackgroundUpdateProvider: @escaping (Wallet) -> any WalletBackgroundUpdateRunning,
        eventCoalescingInterval: TimeInterval = .eventCoalescingInterval
    ) {
        let eventObservers = LockedObserverStore<(wallet: Wallet, event: BackgroundUpdateEvent)>()
        let stateSnapshot = BackgroundUpdateStateSnapshot()
        let (events, eventContinuation) = AsyncStream<BackgroundUpdateEvent>.makeStream()
        let runtime = BackgroundUpdateRuntime(
            walletStore: walletStore,
            runnerProvider: walletBackgroundUpdateProvider,
            eventCoalescingInterval: eventCoalescingInterval,
            eventContinuation: eventContinuation,
            stateSnapshot: stateSnapshot
        )
        let (commands, commandContinuation) = AsyncStream<BackgroundUpdateCommand>.makeStream()

        self.eventObservers = eventObservers
        self.stateSnapshot = stateSnapshot
        self.walletStore = walletStore
        self.commandContinuation = commandContinuation

        commandWorker = Task {
            for await command in commands {
                await runtime.handle(command)
            }
            await runtime.shutdown()
        }

        eventWorker = Task {
            for await event in events {
                eventObservers.notify((event.wallet, event))
            }
        }

        setupObservations()
    }

    deinit {
        commandContinuation.finish()
        eventWorker.cancel()
    }

    public func start() {
        commandContinuation.yield(.start)
    }

    public func stop() {
        commandContinuation.yield(.stop)
    }

    public func reconnect() {
        commandContinuation.yield(.reconnect)
    }

    public func connectionState(walletID: String) -> BackgroundUpdateConnectionState {
        guard let selection = try? walletStore.activeWalletSelection,
              selection.walletID == walletID
        else {
            return .connecting
        }
        return stateSnapshot.state(for: selection)
    }

    /// Level stream: a fresh subscriber immediately receives the current state of every tracked
    /// wallet. Supports any number of independent subscribers.
    public func stateUpdates() -> AsyncStream<BackgroundUpdateStateUpdate> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<BackgroundUpdateStateUpdate>.makeStream()
        continuation.onTermination = { [commandContinuation] _ in
            commandContinuation.yield(.removeStateSubscriber(id))
        }
        commandContinuation.yield(.addStateSubscriber(id, continuation))
        return stream
    }

    /// Delivery is not bound to an executor; observers enter their own isolation domain.
    public func addEventObserver<T: AnyObject>(
        _ observer: T,
        closure: @escaping (T, Wallet, BackgroundUpdateEvent) -> Void
    ) {
        eventObservers.add(observer) { observer, update in
            closure(observer, update.wallet, update.event)
        }
    }

    private func setupObservations() {
        walletStore.addObserver(self) { observer, event in
            switch event {
            case .didChangeActiveWallet:
                guard let selection = try? observer.walletStore.activeWalletSelection else { return }
                observer.commandContinuation.yield(.activeWalletChanged(selection))
            default: break
            }
        }
    }
}

private enum BackgroundUpdateCommand: Sendable {
    case start
    case stop
    case reconnect
    case activeWalletChanged(WalletsStore.ActiveWalletSelection)
    case addStateSubscriber(UUID, AsyncStream<BackgroundUpdateStateUpdate>.Continuation)
    case removeStateSubscriber(UUID)
}

/// The single owner of update lifecycle: desired-running state, the current session and the
/// connection state published to subscribers. Every stale-result check and the mutation it guards
/// happen in one actor turn without an intervening `await`, which is what removes the need for a
/// session generation token.
private actor BackgroundUpdateRuntime {
    private struct Session {
        let selection: WalletsStore.ActiveWalletSelection
        let throttler: BackgroundUpdateEventThrottler
        let connectionTask: Task<Void, Never>
        let eventDeliveryTask: Task<Void, Never>

        func shutdown() {
            connectionTask.cancel()
            eventDeliveryTask.cancel()
            throttler.finish()
        }
    }

    private let walletStore: WalletsStore
    private let runnerProvider: (Wallet) -> any WalletBackgroundUpdateRunning
    private let eventCoalescingInterval: TimeInterval
    private let eventContinuation: AsyncStream<BackgroundUpdateEvent>.Continuation
    private let stateSnapshot: BackgroundUpdateStateSnapshot

    private var desiredRunning = false
    private var activeSelection: WalletsStore.ActiveWalletSelection?
    private var session: Session?
    private var states = [String: BackgroundUpdateStateUpdate]()
    private var stateSubscribers = [UUID: AsyncStream<BackgroundUpdateStateUpdate>.Continuation]()
    private var isShutDown = false

    init(
        walletStore: WalletsStore,
        runnerProvider: @escaping (Wallet) -> any WalletBackgroundUpdateRunning,
        eventCoalescingInterval: TimeInterval,
        eventContinuation: AsyncStream<BackgroundUpdateEvent>.Continuation,
        stateSnapshot: BackgroundUpdateStateSnapshot
    ) {
        self.walletStore = walletStore
        self.runnerProvider = runnerProvider
        self.eventCoalescingInterval = eventCoalescingInterval
        self.eventContinuation = eventContinuation
        self.stateSnapshot = stateSnapshot
    }

    func handle(_ command: BackgroundUpdateCommand) {
        guard !isShutDown else { return }
        switch command {
        case .start:
            desiredRunning = true
            guard let selection = try? walletStore.activeWalletSelection,
                  let wallet = walletStore.getWallet(id: selection.walletID)
            else {
                return
            }
            activeSelection = selection
            startSession(for: wallet, selection: selection)
        case .stop:
            desiredRunning = false
            shutdownSession()
            // Reset the snapshot without notifying: waking UI subscribers here would kick off a
            // total-balance recompute exactly while the app is going into the background.
            states = states.mapValues { update in
                BackgroundUpdateStateUpdate(
                    walletID: update.walletID,
                    walletSelectionID: update.walletSelectionID,
                    state: .connecting
                )
            }
            stateSnapshot.replace(with: states)
        case .reconnect:
            guard desiredRunning,
                  let selection = try? walletStore.activeWalletSelection,
                  let wallet = walletStore.getWallet(id: selection.walletID)
            else {
                return
            }
            activeSelection = selection
            let update = states[selection.walletID]
            let state = update?.walletSelectionID == selection.selectionID ? update?.state : nil
            switch state {
            case .connected, .connecting:
                return
            case .disconnected, .noConnection, .none:
                startSession(for: wallet, selection: selection)
            }
        case let .activeWalletChanged(selection):
            shutdownSession()
            if let previousSelection = activeSelection {
                let update = BackgroundUpdateStateUpdate(
                    walletID: previousSelection.walletID,
                    walletSelectionID: previousSelection.selectionID,
                    state: .connecting
                )
                states[previousSelection.walletID] = update
                stateSnapshot.update(update)
            }
            activeSelection = selection
            guard desiredRunning, let wallet = walletStore.getWallet(id: selection.walletID) else {
                publish(.connecting, selection: selection)
                return
            }
            startSession(for: wallet, selection: selection)
        case let .addStateSubscriber(id, continuation):
            stateSubscribers[id] = continuation
            for update in states.values {
                continuation.yield(update)
            }
        case let .removeStateSubscriber(id):
            stateSubscribers.removeValue(forKey: id)
        }
    }

    func shutdown() {
        guard !isShutDown else { return }
        isShutDown = true
        desiredRunning = false
        shutdownSession()
        for continuation in stateSubscribers.values {
            continuation.finish()
        }
        stateSubscribers.removeAll()
        eventContinuation.finish()
    }

    private func startSession(
        for wallet: Wallet,
        selection: WalletsStore.ActiveWalletSelection
    ) {
        shutdownSession()

        publish(.connecting, selection: selection)

        let runner = runnerProvider(wallet)
        let throttler = BackgroundUpdateEventThrottler(interval: eventCoalescingInterval)

        let connectionTask = Task { [weak self] in
            guard let self else { return }
            await runner.run(
                stateHandler: { state in
                    await self.apply(state: state, selection: selection)
                },
                eventHandler: { event in
                    await self.receive(event: event, selection: selection)
                }
            )
        }

        let eventDeliveryTask = Task { [weak self, events = throttler.events] in
            for await event in events {
                await self?.emit(event: event, selection: selection)
            }
        }

        session = Session(
            selection: selection,
            throttler: throttler,
            connectionTask: connectionTask,
            eventDeliveryTask: eventDeliveryTask
        )
    }

    private func shutdownSession() {
        guard let session else { return }
        self.session = nil
        session.shutdown()
    }

    private func apply(
        state: BackgroundUpdateConnectionState,
        selection: WalletsStore.ActiveWalletSelection
    ) {
        guard isCurrent(selection) else { return }
        publish(state, selection: selection)
    }

    private func receive(
        event: BackgroundUpdateEvent,
        selection: WalletsStore.ActiveWalletSelection
    ) {
        guard isCurrent(selection) else { return }
        session?.throttler.receive(event)
    }

    private func emit(
        event: BackgroundUpdateEvent,
        selection: WalletsStore.ActiveWalletSelection
    ) {
        guard isCurrent(selection) else { return }
        eventContinuation.yield(event)
    }

    private func publish(
        _ state: BackgroundUpdateConnectionState,
        selection: WalletsStore.ActiveWalletSelection
    ) {
        let update = BackgroundUpdateStateUpdate(
            walletID: selection.walletID,
            walletSelectionID: selection.selectionID,
            state: state
        )
        states[selection.walletID] = update
        stateSnapshot.update(update)
        for continuation in stateSubscribers.values {
            continuation.yield(update)
        }
    }

    /// `Task.isCancelled` reads the session task that is calling in, so a cancelled session is
    /// rejected even when its wallet still matches the current one.
    private func isCurrent(_ selection: WalletsStore.ActiveWalletSelection) -> Bool {
        !isShutDown && desiredRunning && !Task.isCancelled && session?.selection == selection
    }
}

private final class BackgroundUpdateStateSnapshot: @unchecked Sendable {
    private let lock = NSLock()
    private var states = [String: BackgroundUpdateStateUpdate]()

    func state(for selection: WalletsStore.ActiveWalletSelection) -> BackgroundUpdateConnectionState {
        lock.withLock {
            guard let update = states[selection.walletID],
                  update.walletSelectionID == selection.selectionID
            else {
                return .connecting
            }
            return update.state
        }
    }

    func update(_ update: BackgroundUpdateStateUpdate) {
        lock.withLock {
            states[update.walletID] = update
        }
    }

    func replace(with states: [String: BackgroundUpdateStateUpdate]) {
        lock.withLock {
            self.states = states
        }
    }
}

private extension TimeInterval {
    static let eventCoalescingInterval: TimeInterval = 2
}

public extension Swift.Error {
    var isNoConnectionError: Bool {
        switch self {
        case let urlError as URLError:
            switch urlError.code {
            case URLError.Code.notConnectedToInternet,
                 URLError.Code.networkConnectionLost:
                return true
            default: return false
            }
        case let clientError as OpenAPIRuntime.ClientError:
            return clientError.underlyingError.isNoConnectionError
        default:
            return false
        }
    }

    var isCancelledError: Bool {
        switch self {
        case _ as CancellationError:
            return true
        case let urlError as URLError:
            switch urlError.code {
            case URLError.Code.cancelled:
                return true
            default: return false
            }
        case let clientError as OpenAPIRuntime.ClientError:
            return clientError.underlyingError.isCancelledError
        case let tonkeeperAPIError as TonkeeperAPIError:
            switch tonkeeperAPIError {
            case .cancelled:
                return true
            default:
                return false
            }
        case let chartServiceError as ChartServiceError:
            switch chartServiceError {
            case .cancelled:
                return true
            default:
                return false
            }
        case let multichainError as MultichainServiceError:
            guard case .cancelled = multichainError else { return false }
            return true
        case let multichainAPIError as MultichainClientAPIError:
            guard case .cancelled = multichainAPIError else { return false }
            return true
        case let rampAPIError as MultichainRampAPIError:
            guard case .cancelled = rampAPIError else { return false }
            return true
        case let deviceAuthError as DeviceAuthError:
            guard case .cancelled = deviceAuthError else { return false }
            return true
        case let tonApiErrorResponse as TonAPI.ErrorResponse:
            switch tonApiErrorResponse {
            case let .error(_, _, _, error):
                return error.isCancelledError
            }
        default:
            return false
        }
    }
}

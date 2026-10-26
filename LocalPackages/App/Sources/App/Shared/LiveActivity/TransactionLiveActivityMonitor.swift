import ActivityKit
import BigInt
import Foundation
import KeeperCore
import PerpsModels
import TKLocalize
import TKLogging
import TronSwift
import UIKit

@MainActor
protocol TransactionLiveActivityMonitoring: AnyObject {
    func setForeground(_ foreground: Bool)
    func historyEntry(transactionId: String, wallet: Wallet) async -> TransactionLiveActivityHistoryEntry?
}

enum TransactionLiveActivityHistoryEntry {
    case multichain(MultichainActivity)
    case ton(AccountEvent)
    case tron(TronTransaction)
}

@available(iOS 16.2, *)
@MainActor
final class TransactionLiveActivityMonitor: TransactionLiveActivityMonitoring {
    private enum Event: Sendable {
        case refresh(after: TimeInterval)
        case secureModeChanged(Bool)
        case transactionSent
        case transactionBroadcast(MultichainPendingTransaction)
        case foregroundPush
        case tonHistoryInvalidated(walletId: String)
        case historyInvalidated(walletId: String)
        case tradingSettled(PerpsTradingSettlement)
    }

    private typealias Load = (snapshots: [TransactionLiveActivitySnapshot], isComplete: Bool)

    nonisolated static let startedIdsKey = "transactionLiveActivity.startedIds"
    /// How long an outcome reached behind the app stays on the Lock Screen. A new activity clears it first.
    private static let outcomeDismissal: TimeInterval = 60 * 60
    /// A send can reach history only after the refresh it triggers; polling covers the gap.
    private static let sendWatch: TimeInterval = 2 * 60
    private static let sendPollIntervals: [TimeInterval] = [5, 10, 20, 30]

    private let walletsStore: WalletsStore
    private let appSettingsStore: AppSettingsStore
    private let multichainService: MultichainService
    private let historyService: HistoryService
    private let tronAPI: TronUSDTAPI
    private let perpsAssembly: PerpsAssembly
    private let realtimeManager: MultichainRealtimeManager

    private var isForeground = false
    /// Held after leaving the foreground while an activity is pending: the system gives about 30 s,
    /// enough for a quick transaction to show its outcome instead of freezing as pending.
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private let refreshQueue = TransactionLiveActivityRefreshQueue()
    private var pollingTask: Task<Void, Never>?
    private var eventTask: Task<Void, Never>?
    private var activityUpdatesTask: Task<Void, Never>?
    private let eventContinuation: AsyncStream<Event>.Continuation
    private var observers: [NSObjectProtocol] = []
    private var watchesSendUntil = Date.distantPast
    private var recentlyBroadcast: [String: TransactionLiveActivitySnapshot] = [:]
    /// When each transaction was first shown: one the person dismissed, or a newer one took over from,
    /// must not come back while it is still pending.
    private var startedIds: [String: Date]
    private var storedCounterparties: TransactionLiveActivityCounterparties?
    /// The journal drops a trading operation once it settles and keeps no verdict.
    private var settledTrading: [String: (settlement: PerpsTradingSettlement, receivedAt: Date)] = [:]
    private var announcedIds: Set<String> = []

    init(
        walletsStore: WalletsStore,
        appSettingsStore: AppSettingsStore,
        multichainService: MultichainService,
        historyService: HistoryService,
        tronAPI: TronUSDTAPI,
        perpsAssembly: PerpsAssembly,
        backgroundUpdate: BackgroundUpdate,
        realtimeManager: MultichainRealtimeManager
    ) {
        self.walletsStore = walletsStore
        self.appSettingsStore = appSettingsStore
        self.multichainService = multichainService
        self.historyService = historyService
        self.tronAPI = tronAPI
        self.perpsAssembly = perpsAssembly
        self.realtimeManager = realtimeManager
        startedIds = Self.loadStartedIds(from: .standard)
        let (events, continuation) = AsyncStream.makeStream(of: Event.self)
        eventContinuation = continuation

        walletsStore.addObserver(self) { _, event in
            switch event {
            case .didAddWallets, .didChangeActiveWallet, .didUpdateWalletMultichain, .didUpdateWalletMetaData,
                 .didDeleteWallet, .didDeleteAll:
                continuation.yield(.refresh(after: 0))
            default:
                break
            }
        }
        appSettingsStore.addObserver(self) { _, event in
            if case let .didUpdateIsSecureMode(isSecureMode) = event {
                continuation.yield(.secureModeChanged(isSecureMode))
            }
        }
        realtimeManager.addHistoryInvalidationObserver(self) { _, walletId in
            continuation.yield(.historyInvalidated(walletId: walletId))
        }
        backgroundUpdate.addEventObserver(self) { _, wallet, _ in
            continuation.yield(.tonHistoryInvalidated(walletId: wallet.id))
        }
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .transactionSendNotification, object: nil, queue: nil) { _ in
            continuation.yield(.transactionSent)
        })
        observers.append(center.addObserver(forName: .multichainTransactionBroadcast, object: nil, queue: nil) { notification in
            guard let transaction = notification.object as? MultichainPendingTransaction else { return }
            continuation.yield(.transactionBroadcast(transaction))
        })
        observers.append(center.addObserver(forName: .foregroundPushReceived, object: nil, queue: nil) { _ in
            continuation.yield(.foregroundPush)
        })
        observers.append(center.addObserver(forName: TransactionLiveActivityMock.didChangeNotification, object: nil, queue: nil) { _ in
            continuation.yield(.refresh(after: 0))
        })
        observers.append(center.addObserver(
            forName: .perpsTradingOperationSettled,
            object: nil,
            queue: nil
        ) { notification in
            guard let settlement = notification.object as? PerpsTradingSettlement else { return }
            continuation.yield(.tradingSettled(settlement))
        })
        eventTask = Task { [weak self] in
            for await event in events {
                await self?.handle(event)
            }
        }
        activityUpdatesTask = Task { [weak self] in
            for await activity in Activity<TransactionLiveActivityAttributes>.activityUpdates {
                self?.adopt(activity)
            }
        }
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
        eventContinuation.finish()
        eventTask?.cancel()
        activityUpdatesTask?.cancel()
        pollingTask?.cancel()
        // The owning coordinator is torn down on delete-all before the store event reaches a refresh,
        // and nothing else would end the removed wallets' activities or the background time held.
        let walletsStore = walletsStore
        let backgroundTask = backgroundTask
        Task { @MainActor in
            for activity in Activity<TransactionLiveActivityAttributes>.activities
                where walletsStore.getWallet(id: activity.attributes.walletId) == nil
            {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            if backgroundTask != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTask)
            }
        }
    }

    func setForeground(_ foreground: Bool) {
        guard isForeground != foreground else { return }
        isForeground = foreground
        pollingTask?.cancel()
        if foreground {
            endBackgroundTime()
            eventContinuation.yield(.refresh(after: 0))
            startPolling(every: 30)
        } else if Self.currentActivity?.content.state.status == .pending, beginBackgroundTime() {
            startPolling(every: 10)
        } else {
            stopRefreshing()
        }
    }

    private var canRefresh: Bool {
        isForeground || backgroundTask != .invalid
    }

    /// New transactions are found through wallet events; polling only follows one already on show,
    /// or a send history has not caught up with yet.
    private var needsPolling: Bool {
        Self.currentActivity?.content.state.status == .pending || watchesSendUntil > Date()
    }

    private func startPolling(every interval: TimeInterval) {
        pollingTask = Task { [weak self] in
            var sendPollAttempt = 0
            while !Task.isCancelled {
                let isWatchingForSend = self?.isForeground == true
                    && (self?.watchesSendUntil ?? .distantPast) > Date()
                let delay = isWatchingForSend
                    ? Self.sendPollIntervals[min(sendPollAttempt, Self.sendPollIntervals.count - 1)]
                    : interval
                sendPollAttempt = isWatchingForSend ? sendPollAttempt + 1 : 0
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled, let self else { return }
                if needsPolling {
                    eventContinuation.yield(.refresh(after: 0))
                }
            }
        }
    }

    private func stopRefreshing() {
        refreshQueue.cancel()
        pollingTask?.cancel()
    }

    private func beginBackgroundTime() -> Bool {
        // Runs on the main thread, and the task must be ended before it returns: the app may be
        // suspended right after, and holding the task at that point gets it terminated.
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "TransactionLiveActivity") { [weak self] in
            self?.stopRefreshing()
            self?.endBackgroundTime()
        }
        return backgroundTask != .invalid
    }

    private func endBackgroundTime() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }

    private func endBackgroundTimeIfSettled() {
        guard !isForeground, backgroundTask != .invalid,
              Self.currentActivity?.content.state.status != .pending
        else { return }
        stopRefreshing()
        endBackgroundTime()
    }

    private func recordSettlement(_ settlement: PerpsTradingSettlement) {
        let now = Date()
        settledTrading = settledTrading.filter { now.timeIntervalSince($0.value.receivedAt) < 60 * 60 }
        settledTrading[settlement.action.operationId] = (settlement, now)
        scheduleRefresh()
    }

    private func handle(_ event: Event) async {
        switch event {
        case let .refresh(delay):
            scheduleRefresh(after: delay)
        case let .secureModeChanged(isSecureMode):
            if isSecureMode {
                refreshQueue.cancel()
                await redactActivities()
                await refreshQueue.waitForCurrent()
                if appSettingsStore.getState().isSecureMode {
                    await redactActivities()
                }
            }
            scheduleRefresh()
        case .transactionSent:
            watchesSendUntil = Date().addingTimeInterval(Self.sendWatch)
            if isForeground {
                pollingTask?.cancel()
                startPolling(every: 30)
            }
            scheduleRefresh()
        case let .transactionBroadcast(transaction):
            guard let wallet = try? walletsStore.activeWallet,
                  wallet.multichainWalletState?.walletId == transaction.walletId
            else { return }
            guard !transaction.txHash.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            let snapshot = TransactionLiveActivitySnapshot(broadcast: transaction)
            recentlyBroadcast[Self.key(walletId: wallet.id, transactionId: snapshot.id)] = snapshot
            watchesSendUntil = Date().addingTimeInterval(Self.sendWatch)
            if isForeground {
                pollingTask?.cancel()
                startPolling(every: 30)
                if Self.currentActivity == nil {
                    await reconcile(
                        [snapshot],
                        perpsLoaded: false,
                        walletId: wallet.id,
                        walletMetaData: wallet.metaData
                    )
                }
            }
            scheduleRefresh()
        case .foregroundPush:
            scheduleRefresh()
        case let .tonHistoryInvalidated(walletId):
            guard (try? walletsStore.activeWallet.id) == walletId else { return }
            scheduleRefresh()
        case let .historyInvalidated(walletId):
            guard (try? walletsStore.activeWallet.multichainWalletState?.walletId) == walletId else { return }
            // Invalidations come in bursts; one refresh answers them all.
            scheduleRefresh(after: 0.5)
        case let .tradingSettled(settlement):
            recordSettlement(settlement)
        }
    }

    private func redactActivities() async {
        for activity in Activity<TransactionLiveActivityAttributes>.activities {
            let content = activity.content
            let redacted = Self.redactedState(from: activity.transactionState)
            guard redacted != content.state else { continue }
            switch activity.activityState {
            case .active, .stale:
                await activity.update(ActivityContent(state: redacted, staleDate: content.staleDate))
            case .ended:
                // An outcome left on the Lock Screen takes no more updates.
                await activity.end(nil, dismissalPolicy: .immediate)
            default:
                break
            }
        }
    }

    /// An activity surviving an app restart still counts as started, so dismissing it does not
    /// start it again while the same transaction is pending.
    private func adopt(_ activity: Activity<TransactionLiveActivityAttributes>) {
        let key = Self.key(walletId: activity.attributes.walletId, transactionId: activity.transactionState.transactionId)
        guard startedIds[key] == nil else { return }
        startedIds[key] = Date()
        persistStartedIds()
        scheduleRefresh()
    }

    private func scheduleRefresh(after delay: TimeInterval = 0) {
        guard canRefresh else { return }
        refreshQueue.schedule(after: delay, onFinish: { [weak self] in
            guard !Task.isCancelled else { return }
            self?.endBackgroundTimeIfSettled()
        }) { [weak self] finalization in
            await self?.refresh(finalization: finalization)
        }
    }

    private func refresh(finalization: TransactionLiveActivityRefreshFinalization) async {
        storeCounterparties()
        let wallet = try? walletsStore.activeWallet
        let walletId = wallet?.id
        guard isCurrent(walletId: walletId) else { return }
        await endActivities(outside: walletId)
        guard isCurrent(walletId: walletId), let wallet else { return }

        let mocks = TransactionLiveActivityMock.snapshots()
        if !mocks.isEmpty {
            // Mocks need no network, so they are answered first: a start has to land while the app is in front.
            await reconcile(mocks, perpsLoaded: false, walletId: wallet.id, walletMetaData: wallet.metaData)
            guard isCurrent(walletId: walletId) else { return }
        }
        var snapshots = mocks
        var perpsLoaded = false

        if let state = wallet.multichainWalletState {
            let scope = perpsAssembly.walletScope(for: wallet)
            for (settlement, _) in settledTrading.values where settlement.action.walletId == wallet.id {
                let symbol = await scope.marketSymbol(marketId: settlement.action.marketId)
                snapshots.append(TransactionLiveActivitySnapshot(
                    trading: settlement.action,
                    marketSymbol: symbol,
                    status: settlement.succeeded ? .confirmed : .failed
                ))
            }
            do {
                let operations = try await scope.pendingActivityOperations()
                for trading in operations.trading where trading.walletId == wallet.id
                    && !(trading.signedSteps?.isEmpty ?? true)
                {
                    let symbol = await scope.marketSymbol(marketId: trading.marketId)
                    snapshots.append(TransactionLiveActivitySnapshot(trading: trading, marketSymbol: symbol))
                }
                snapshots += operations.funding
                    .filter { $0.walletId == state.walletId && !$0.isBeforeSideEffect }
                    .map { TransactionLiveActivitySnapshot(funding: $0) }
                perpsLoaded = true
            } catch {
                Log.e("Live Activity perps refresh failed: \(error)")
            }
        }
        guard isCurrent(walletId: walletId) else { return }
        // The journal settles a perps operation ahead of any history, while a newer transaction can only
        // be found in the history loaded below.
        if Self.currentActivity?.transactionState.transactionId.hasPrefix("perps-") == true {
            await reconcile(
                snapshots,
                perpsLoaded: perpsLoaded,
                walletId: wallet.id,
                walletMetaData: wallet.metaData,
                startPending: false,
                finalization: finalization
            )
            guard isCurrent(walletId: walletId) else { return }
        }

        async let multichain = multichainSnapshots(for: wallet)
        async let ton = tonSnapshots(for: wallet)
        async let tron = tronSnapshots(for: wallet)
        let multichainLoad = await multichain
        guard isCurrent(walletId: walletId) else { return }
        snapshots += multichainLoad.snapshots
        let pendingLocalSnapshots = localSnapshots(for: wallet, excluding: snapshots)
        // A start waits for TON and TRON: a newer pending transaction may be only in their history.
        await reconcile(
            snapshots + pendingLocalSnapshots,
            perpsLoaded: perpsLoaded,
            walletId: wallet.id,
            walletMetaData: wallet.metaData,
            startPending: false,
            finalization: finalization
        )
        guard isCurrent(walletId: walletId) else { return }

        let loads = await(ton: ton, tron: tron)
        guard isCurrent(walletId: walletId) else { return }
        snapshots += loads.ton.snapshots + loads.tron.snapshots
        let remainingLocalSnapshots = localSnapshots(for: wallet, excluding: snapshots)

        // A source that failed may be the one holding the current transaction.
        let currentChain = Self.currentActivity.flatMap {
            TransactionLiveActivitySelection.chain(of: $0.transactionState.transactionId)
        }
        let judgesAbsence = multichainLoad.isComplete
            && (loads.ton.isComplete || currentChain != MultichainChain.ton.rawValue)
            && (loads.tron.isComplete || currentChain != MultichainChain.tron.rawValue)
        await reconcile(
            snapshots + remainingLocalSnapshots,
            perpsLoaded: perpsLoaded,
            walletId: wallet.id,
            walletMetaData: wallet.metaData,
            judgesAbsence: judgesAbsence,
            finalization: finalization
        )
    }

    private func localSnapshots(
        for wallet: Wallet,
        excluding snapshots: [TransactionLiveActivitySnapshot]
    ) -> [TransactionLiveActivitySnapshot] {
        let now = Date()
        let walletPrefix = "\(wallet.id):"
        recentlyBroadcast = recentlyBroadcast.filter { key, snapshot in
            now.timeIntervalSince(snapshot.date) < Self.sendWatch
                && (!key.hasPrefix(walletPrefix)
                    || TransactionLiveActivitySelection.matching(snapshot.id, in: snapshots) == nil)
        }
        return recentlyBroadcast.compactMap { key, snapshot in
            key.hasPrefix(walletPrefix) ? snapshot : nil
        }
    }

    /// Matched the way a refresh matches the activity, so a transfer that turned out to be the leg of a
    /// swap leads to the swap. The wallet's own history comes first; a TON or TRON one only when that
    /// history has no such entry.
    func historyEntry(transactionId: String, wallet: Wallet) async -> TransactionLiveActivityHistoryEntry? {
        let multichain = await multichainSnapshots(for: wallet)
        if let entry = TransactionLiveActivitySelection.matching(transactionId, in: multichain.snapshots)?.historyEntry {
            return entry
        }
        let chain = TransactionLiveActivitySelection.chain(of: transactionId)
        let snapshots: [TransactionLiveActivitySnapshot]
        if chain == MultichainChain.ton.rawValue {
            snapshots = await tonSnapshots(for: wallet).snapshots
        } else if chain == MultichainChain.tron.rawValue {
            snapshots = await tronSnapshots(for: wallet).snapshots
        } else {
            return nil
        }
        return TransactionLiveActivitySelection.matching(transactionId, in: snapshots)?.historyEntry
    }

    private func multichainSnapshots(for wallet: Wallet) async -> Load {
        guard let state = wallet.multichainWalletState else { return ([], true) }
        do {
            let page = try await multichainService.getWalletActivities(
                state: state,
                limit: 50,
                cursor: nil,
                chain: nil,
                assetId: nil,
                activityTypeFilter: nil,
                showPerps: true,
                market: nil,
                // Address poisoning plants its lookalike sender through a dust transfer.
                hideDust: true
            )
            return (page.activities.compactMap(TransactionLiveActivitySnapshot.init), true)
        } catch {
            Log.e("Live Activity multichain refresh failed: \(error)")
            return ([], false)
        }
    }

    private func tonSnapshots(for wallet: Wallet) async -> Load {
        do {
            let events = try await historyService.loadEvents(wallet: wallet, beforeLt: nil, limit: 30)
            return (events.events.map { TransactionLiveActivitySnapshot(event: $0, wallet: wallet) }, true)
        } catch {
            Log.e("Live Activity TON refresh failed: \(error)")
            return ([], false)
        }
    }

    private func tronSnapshots(for wallet: Wallet) async -> Load {
        guard let address = wallet.tron?.address else { return ([], true) }
        var snapshots: [TransactionLiveActivitySnapshot] = []
        var isComplete = true
        do {
            let batteryEvents = try await tronAPI.loadBatteryTronEvents(
                wallet: wallet,
                events: [],
                address: address,
                limit: 30,
                startTimestamp: nil,
                finishTimestamp: nil
            )
            snapshots += batteryEvents.map { TransactionLiveActivitySnapshot(transaction: $0, walletAddress: address) }
            let chainEvents = try await tronAPI.loadTronEvents(
                events: [],
                address: address,
                limit: 30,
                startTimestamp: nil,
                finishTimestamp: nil
            )
            snapshots += chainEvents.map { TransactionLiveActivitySnapshot(transaction: $0, walletAddress: address) }
        } catch {
            Log.e("Live Activity TRON USDT refresh failed: \(error)")
            isComplete = false
        }
        do {
            try await Task.sleep(for: .seconds(1))
            let events = try await tronAPI.loadTRXTransfers(address: address, limit: 30, startTimestamp: nil)
            snapshots += events.map { TransactionLiveActivitySnapshot(transaction: $0, walletAddress: address) }
        } catch {
            Log.e("Live Activity TRON TRX refresh failed: \(error)")
            isComplete = false
        }
        return (snapshots, isComplete)
    }

    /// - Parameter startPending: Whether the snapshots are complete enough to pick the transaction to show
    ///   next. A partial outcome waits for the full pass, or is finalized when this refresh exits.
    private func reconcile(
        _ snapshots: [TransactionLiveActivitySnapshot],
        perpsLoaded: Bool,
        walletId: String,
        walletMetaData: WalletMetaData,
        startPending: Bool = true,
        judgesAbsence: Bool = false,
        finalization: TransactionLiveActivityRefreshFinalization? = nil
    ) async {
        let hidesAmounts = appSettingsStore.getState().isSecureMode
        let current = Self.currentActivity
        let previousIds = startedIds
        if let current {
            let key = Self.key(walletId: walletId, transactionId: current.transactionState.transactionId)
            startedIds[key] = startedIds[key] ?? Date()
        }
        for snapshot in snapshots where snapshot.status != .pending {
            for id in snapshot.matchingIds {
                startedIds[Self.key(walletId: walletId, transactionId: id)] = nil
            }
        }
        if previousIds != startedIds { persistStartedIds() }
        let candidate = startPending
            ? TransactionLiveActivitySelection.nextPending(in: snapshots, excluding: Set(startedIds.keys), walletId: walletId)
            : nil
        let state = { (snapshot: TransactionLiveActivitySnapshot) in
            Self.contentState(for: snapshot, walletMetaData: walletMetaData, hidesAmounts: hidesAmounts)
        }

        guard let current else {
            guard isForeground, ActivityAuthorizationInfo().areActivitiesEnabled, let candidate else { return }
            await request(candidate, state: state(candidate), walletId: walletId)
            return
        }
        let currentState = current.transactionState
        switch TransactionLiveActivitySelection.step(
            tracking: currentState.transactionId,
            status: currentState.status,
            updatedAt: currentState.updatedAt,
            in: snapshots,
            next: candidate,
            perpsLoaded: perpsLoaded,
            judgesAbsence: judgesAbsence
        ) {
        case .stay:
            return
        case let .follow(snapshot):
            let unchangedState = Self.contentState(
                for: snapshot,
                walletMetaData: walletMetaData,
                hidesAmounts: hidesAmounts,
                updatedAt: currentState.updatedAt
            )
            if unchangedState != currentState {
                await current.update(Self.content(for: state(snapshot)))
            }
        case let .replace(snapshot):
            await show(snapshot, state: state(snapshot), on: current, walletId: walletId)
        case let .settle(outcome, next):
            let outcomeState = switch outcome {
            case .shown: currentState
            case let .reached(snapshot): state(snapshot)
            case .unknown: Self.unknownState(from: currentState)
            }
            await announce(outcomeState, on: current, walletId: walletId)
            if !startPending, canRefresh, let finalization {
                finalization.set { [self] in
                    guard current.activityState == .active || current.activityState == .stale else { return }
                    await end(current, with: outcomeState)
                }
                return
            }
            if let next, isCurrent(walletId: walletId) {
                await show(next, state: state(next), on: current, walletId: walletId)
            } else {
                await end(current, with: outcomeState)
            }
            finalization?.clear()
        }
    }

    private func request(
        _ snapshot: TransactionLiveActivitySnapshot,
        state: TransactionLiveActivityAttributes.ContentState,
        walletId: String
    ) async {
        guard isForeground, isCurrent(walletId: walletId),
              ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // An outcome left on the Lock Screen would stand next to the new activity.
        for activity in Activity<TransactionLiveActivityAttributes>.activities where activity.activityState == .ended {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        guard isForeground, isCurrent(walletId: walletId), Self.currentActivity == nil else { return }
        do {
            // Backend does not send ActivityKit updates yet. Restore .token and token registration with that API.
            _ = try Activity.request(
                attributes: TransactionLiveActivityAttributes(walletId: walletId),
                content: Self.content(for: state),
                pushType: nil
            )
            startedIds[Self.key(walletId: walletId, transactionId: snapshot.id)] = Date()
            persistStartedIds()
        } catch {
            Log.e("Live Activity request failed: \(error)")
        }
    }

    /// The transaction it takes over from is not brought back: it goes on in history and in its push.
    private func show(
        _ snapshot: TransactionLiveActivitySnapshot,
        state: TransactionLiveActivityAttributes.ContentState,
        on activity: Activity<TransactionLiveActivityAttributes>,
        walletId: String
    ) async {
        guard activity.activityState == .active || activity.activityState == .stale else {
            await request(snapshot, state: state, walletId: walletId)
            return
        }
        startedIds[Self.key(walletId: walletId, transactionId: snapshot.id)] = Date()
        persistStartedIds()
        await activity.update(Self.content(for: state))
    }

    /// The island drops an ended activity at once and the app is not on screen in the background, so
    /// there the outcome is shown in place for a moment first — within the background time left — with
    /// an alert that expands the island and plays the sound. The system presents no alert over the app
    /// itself, so in the foreground the outcome is a haptic. A cancel only cuts the pause short.
    private func announce(
        _ state: TransactionLiveActivityAttributes.ContentState,
        on activity: Activity<TransactionLiveActivityAttributes>,
        walletId: String
    ) async {
        guard announcedIds.insert(Self.key(walletId: walletId, transactionId: state.transactionId)).inserted
        else { return }
        let feedback: UINotificationFeedbackGenerator.FeedbackType? = switch state.status {
        case .confirmed: .success
        case .failed, .dropped: .error
        case .pending, .unknown: nil
        }
        if isForeground {
            if let feedback {
                UINotificationFeedbackGenerator().notificationOccurred(feedback)
            }
            return
        }
        let pause = min(4, UIApplication.shared.backgroundTimeRemaining - 2)
        guard pause >= 1 else { return }
        if activity.content.state.status == .pending {
            await activity.update(
                ActivityContent(state: state, staleDate: nil),
                alertConfiguration: feedback.map { _ in Self.alert(for: state, walletId: walletId) }
            )
        }
        try? await Task.sleep(for: .seconds(pause))
    }

    /// In front of the app nothing is left to show; behind it the outcome stays for a glance.
    private func end(
        _ activity: Activity<TransactionLiveActivityAttributes>,
        with state: TransactionLiveActivityAttributes.ContentState
    ) async {
        let finalState = appSettingsStore.getState().isSecureMode ? Self.redactedState(from: state) : state
        await activity.end(
            ActivityContent(state: finalState, staleDate: nil),
            dismissalPolicy: isForeground ? .immediate : .after(Date().addingTimeInterval(Self.outcomeDismissal))
        )
    }

    private static func alert(
        for state: TransactionLiveActivityAttributes.ContentState,
        walletId: String
    ) -> AlertConfiguration {
        let counterparties = TransactionLiveActivityCounterparties.load()
        let presentation = TransactionLiveActivityPresentation(state: state, isStale: false) {
            counterparties.label(for: $0, shownWalletId: walletId)
        }
        // Interpolated, the text is an argument: a token symbol is neither a lookup key nor a format.
        return AlertConfiguration(
            title: LocalizedStringResource("\(presentation.title)"),
            body: LocalizedStringResource("\(presentation.amount?.text ?? presentation.subtitle ?? "")"),
            sound: .default
        )
    }

    /// The widget names an own-wallet counterparty from this copy, which also serves pushed states.
    private func storeCounterparties() {
        let counterparties = TransactionLiveActivityCounterparties(walletsStore.wallets)
        guard counterparties != storedCounterparties else { return }
        storedCounterparties = counterparties
        counterparties.save()
    }

    /// The shown wallet keeps its one live activity; another wallet's has no place on screen.
    private func endActivities(outside walletId: String?) async {
        var keepsLive = false
        for activity in Activity<TransactionLiveActivityAttributes>.activities {
            let isLive = activity.activityState == .active || activity.activityState == .stale
            if activity.attributes.walletId == walletId {
                guard isLive else { continue }
                guard keepsLive else {
                    keepsLive = true
                    continue
                }
            } else if isLive {
                // Its transaction starts again on return to the wallet, unless the person dismissed it.
                let key = Self.key(
                    walletId: activity.attributes.walletId,
                    transactionId: activity.transactionState.transactionId
                )
                if startedIds.removeValue(forKey: key) != nil { persistStartedIds() }
            }
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private func isCurrent(walletId: String?) -> Bool {
        canRefresh && !Task.isCancelled
            && (try? walletsStore.activeWallet.id) == walletId
    }

    private static var currentActivity: Activity<TransactionLiveActivityAttributes>? {
        Activity<TransactionLiveActivityAttributes>.activities.first {
            $0.activityState == .active || $0.activityState == .stale
        }
    }

    private static func key(walletId: String, transactionId: String) -> String {
        "\(walletId):\(transactionId.lowercased())"
    }

    private func persistStartedIds() {
        startedIds = Self.pruned(startedIds, now: Date())
        UserDefaults.standard.set(startedIds, forKey: Self.startedIdsKey)
    }

    nonisolated static func loadStartedIds(from defaults: UserDefaults, now: Date = Date()) -> [String: Date] {
        pruned(defaults.dictionary(forKey: startedIdsKey) as? [String: Date] ?? [:], now: now)
    }

    /// Past the start window its transaction is never started again, so the entry guards nothing.
    nonisolated static func pruned(_ startedIds: [String: Date], now: Date) -> [String: Date] {
        startedIds.filter { now.timeIntervalSince($0.value) < TransactionLiveActivitySelection.startWindow }
    }

    nonisolated static func contentState(
        for snapshot: TransactionLiveActivitySnapshot,
        walletMetaData: WalletMetaData,
        hidesAmounts: Bool = false,
        updatedAt: Date = Date()
    ) -> TransactionLiveActivityAttributes.ContentState {
        let (emoji, icon): (String?, String?) = switch walletMetaData.icon {
        case let .emoji(value): (value, nil)
        case let .icon(image): (nil, image.rawValue)
        }
        let state = TransactionLiveActivityAttributes.ContentState(
            transactionId: snapshot.id,
            chain: snapshot.chain,
            detail: snapshot.detail,
            status: snapshot.status,
            title: snapshot.title,
            updatedAt: updatedAt,
            source: snapshot.source,
            destination: snapshot.destination,
            kind: snapshot.kind,
            wallet: .init(name: walletMetaData.label, emoji: emoji, icon: icon),
            counterpartyAddress: snapshot.counterpartyAddress,
            stage: snapshot.stage,
            perpsMarketId: snapshot.perpsMarketId
        )
        return hidesAmounts ? redactedState(from: state) : state
    }

    nonisolated static func redactedState(
        from state: TransactionLiveActivityAttributes.ContentState
    ) -> TransactionLiveActivityAttributes.ContentState {
        .init(
            transactionId: state.transactionId,
            chain: state.chain,
            detail: state.detail,
            status: state.status,
            title: state.title,
            updatedAt: state.updatedAt,
            source: state.source.map { .init(network: $0.network, currency: $0.currency, amount: nil) },
            destination: state.destination.map { .init(network: $0.network, currency: $0.currency, amount: nil) },
            kind: state.kind,
            wallet: state.wallet,
            counterpartyAddress: nil,
            stage: state.stage,
            perpsMarketId: state.perpsMarketId
        )
    }

    private static func unknownState(
        from state: TransactionLiveActivityAttributes.ContentState
    ) -> TransactionLiveActivityAttributes.ContentState {
        .init(
            transactionId: state.transactionId,
            chain: state.chain,
            detail: state.detail,
            status: .unknown,
            title: TKLocales.LiveActivity.statusMayHaveChanged,
            updatedAt: Date(),
            source: state.source,
            destination: state.destination,
            kind: state.kind,
            wallet: state.wallet,
            counterpartyAddress: state.counterpartyAddress,
            stage: nil,
            perpsMarketId: state.perpsMarketId
        )
    }

    private static func content(
        for state: TransactionLiveActivityAttributes.ContentState
    ) -> ActivityContent<TransactionLiveActivityAttributes.ContentState> {
        ActivityContent(state: state, staleDate: state.status == .pending ? Date().addingTimeInterval(5 * 60) : nil)
    }
}

@available(iOS 16.2, *)
struct TransactionLiveActivitySnapshot {
    typealias Status = TransactionLiveActivityAttributes.ContentState.Status
    typealias Leg = TransactionLiveActivityAttributes.ContentState.Leg
    typealias Kind = TransactionLiveActivityAttributes.ContentState.Kind
    typealias Stage = TransactionLiveActivityAttributes.ContentState.Stage

    let id: String
    let matchingIds: Set<String>
    /// The chain transactions behind it. An exchange keeps them apart from `matchingIds`: its source
    /// leg confirming on its own chain is not the outcome of the whole swap.
    let transactionIds: Set<String>
    let isExchange: Bool
    let date: Date
    let status: Status
    let title: String
    /// Set only while a multi-stage operation is pending; `title` then names the stage.
    let stage: Stage?
    let chain: String
    let detail: String?
    let source: Leg?
    let destination: Leg?
    let kind: Kind
    let counterpartyAddress: String?
    let isSpam: Bool
    let historyEntry: TransactionLiveActivityHistoryEntry?
    private(set) var perpsMarketId: Int64?

    init(broadcast transaction: MultichainPendingTransaction, date: Date = Date()) {
        let transactionId = Self.normalizedId(transaction.txHash, chain: transaction.chain)
        let isExchange: Bool
        if case .swap = transaction.activityType {
            isExchange = true
        } else {
            isExchange = false
        }
        id = isExchange ? TransactionLiveActivitySelection.exchangePrefix + transactionId : transactionId
        matchingIds = [id]
        transactionIds = [transactionId]
        self.isExchange = isExchange
        self.date = date
        status = .pending
        let destinationChain: MultichainChain? = if case let .swap(details) = transaction.activityType {
            MultichainChain(assetId: details.toAssetId)
        } else {
            nil
        }
        let staged = destinationChain.flatMap { destination in
            destination == transaction.chain
                ? nil
                : Self.crossChainStage(to: destination, currency: nil, isIndexed: false, isArriving: false)
        }
        stage = staged?.stage
        title = staged?.title ?? Self.title(.pending, isExchange ? .swap : transaction.activityType == .send ? .send : nil)
        let network = transaction.chain.rawValue.uppercased()
        chain = network
        detail = nil
        source = Leg(network: network, currency: nil, amount: nil)
        destination = nil
        kind = isExchange ? .swap : transaction.activityType == .send ? .send : .other
        counterpartyAddress = nil
        isSpam = false
        historyEntry = nil
    }

    init?(activity: MultichainActivity) {
        let isExchange = activity.activityType == .swap || activity.activityType == .bridge
        let transactionIds = activity.txIds
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { Self.normalizedId($0, chain: activity.fromChain ?? activity.toChain) }
        let identifiers = isExchange ? transactionIds.map { TransactionLiveActivitySelection.exchangePrefix + $0 } : transactionIds
        guard let firstId = identifiers.first else { return nil }
        id = firstId
        matchingIds = Set(identifiers)
        self.transactionIds = Set(transactionIds)
        self.isExchange = isExchange
        date = activity.blockTime
        isSpam = activity.isSpam
        let sameChain = activity.fromChain == nil || activity.toChain == nil
            || activity.fromChain == activity.toChain
        let sourceToken = activity.outToken ?? (!isExchange && sameChain ? activity.inToken : nil)
        let destinationToken = activity.inToken ?? (!isExchange && sameChain ? activity.outToken : nil)
        source = Leg(
            network: (activity.outToken?.chain ?? activity.fromChain ?? sourceToken?.chain ?? activity.toChain)?.rawValue.uppercased(),
            currency: sourceToken?.symbol,
            amount: Self.compactAmount(activity.outAmount, decimals: sourceToken?.decimals)
        )
        destination = Leg(
            network: (activity.inToken?.chain ?? activity.toChain ?? destinationToken?.chain ?? activity.fromChain)?.rawValue.uppercased(),
            currency: destinationToken?.symbol,
            amount: Self.compactAmount(activity.inAmount, decimals: destinationToken?.decimals)
        )
        kind = if isExchange {
            .swap
        } else if activity.activityType.isPerps {
            .other
        } else {
            switch activity.direction {
            case .incoming: .receive
            case .outgoing: .send
            case .selfTransfer: .other
            }
        }
        counterpartyAddress = switch kind {
        case .send: activity.toAddress
        case .receive: activity.fromAddress
        case .swap, .other: nil
        }
        chain = (isExchange || activity.direction == .incoming
            ? activity.toChain ?? activity.fromChain
            : activity.fromChain ?? activity.toChain)?.rawValue.uppercased() ?? ""
        if isExchange, let outToken = activity.outToken, let inToken = activity.inToken {
            detail = "\(outToken.symbol) → \(inToken.symbol)"
        } else if isExchange, let fromChain = activity.fromChain, let toChain = activity.toChain,
                  fromChain != toChain
        {
            detail = "\(fromChain.rawValue.uppercased()) → \(toChain.rawValue.uppercased())"
        } else {
            detail = activity.perps?.symbol ?? (activity.direction == .incoming ? activity.inToken?.symbol : nil)
        }
        let presentation: MultichainActivityPresentationKind =
            isExchange && activity.outToken != nil && activity.inToken != nil
                ? .swap : MultichainActivityPresentationKind(activity: activity)
        status = switch activity.status {
        case .pending: .pending
        case .confirmed: .confirmed
        case .failed: .failed
        case .dropped: .dropped
        }
        let staged: (stage: Stage, title: String)? = if status == .pending, isExchange, !sameChain,
                                                        let toChain = activity.toChain
        {
            Self.crossChainStage(
                to: toChain,
                currency: destinationToken?.symbol,
                isIndexed: true,
                isArriving: transactionIds.contains { $0.hasPrefix("\(toChain.rawValue):") }
            )
        } else {
            nil
        }
        stage = staged?.stage
        title = staged?.title ?? Self.title(status, presentation)
        historyEntry = .multichain(activity)
    }

    init(event: AccountEvent, wallet: Wallet) {
        let isSwap = event.actions.contains { action in
            if case .jettonSwap = action.type { return true }
            return false
        }
        let transactionId = Self.normalizedId(event.eventId, chain: .ton)
        id = isSwap ? TransactionLiveActivitySelection.exchangePrefix + transactionId : transactionId
        matchingIds = [id]
        transactionIds = [transactionId]
        isExchange = isSwap
        date = event.date
        let failed = !event.actions.isEmpty && event.actions.allSatisfy { action in
            if case .failed = action.status { return true }
            return false
        }
        status = event.isInProgress ? .pending : failed ? .failed : .confirmed
        let historyEvent = HistoryEvent.tonAccountEvent(event)
        let incoming = historyEvent.isReceived(wallet: wallet)
        let outgoing = historyEvent.isSent(wallet: wallet)
        let presentation: MultichainActivityPresentationKind? = if isSwap {
            .swap
        } else if incoming, !outgoing {
            .receive
        } else if outgoing, !incoming {
            .send
        } else {
            nil
        }
        title = Self.title(status, presentation)
        stage = nil
        kind = switch presentation {
        case .send: .send
        case .receive: .receive
        case .swap: .swap
        default: .other
        }
        let transferAction = event.actions.first { action in
            switch action.type {
            case .tonTransfer, .jettonTransfer: true
            default: false
            }
        }
        // The owner's wallet, not the jetton wallet a jetton transfer moves between.
        let counterparty: WalletAccount? = switch (kind, transferAction?.type) {
        case let (.send, .tonTransfer(transfer)): transfer.recipient
        case let (.receive, .tonTransfer(transfer)): transfer.sender
        case let (.send, .jettonTransfer(transfer)): transfer.recipient
        case let (.receive, .jettonTransfer(transfer)): transfer.sender
        default: nil
        }
        counterpartyAddress = counterparty.map {
            $0.address.toFriendly(testOnly: wallet.network == .testnet, bounceable: !$0.isWallet).toString()
        }
        chain = "TON"
        detail = nil
        let primaryAction = event.actions.first { action in
            if case .jettonSwap = action.type { return true }
            return false
        }
        let legs = primaryAction.flatMap { Self.tonLegs($0, isIncoming: false) }
            ?? event.actions.compactMap { Self.tonLegs($0, isIncoming: incoming && !outgoing) }.first
        (source, destination) = legs
            ?? (Leg(network: "TON", currency: nil, amount: nil), Leg(network: "TON", currency: nil, amount: nil))
        isSpam = event.isScam
        historyEntry = .ton(event)
    }

    init(transaction: TronTransaction, walletAddress: TronSwift.Address? = nil) {
        id = Self.normalizedId(transaction.txID, chain: .tron)
        matchingIds = [id]
        transactionIds = [id]
        isExchange = false
        date = Date(timeIntervalSince1970: TimeInterval(transaction.timestamp))
        status = transaction.isPending ? .pending : transaction.isFailed ? .failed : .confirmed
        let presentation: MultichainActivityPresentationKind? = walletAddress.map {
            transaction.getTransactionType(address: $0) == .receive ? .receive : .send
        }
        title = Self.title(status, presentation)
        stage = nil
        chain = "TRON"
        detail = transaction.token == .usdt ? "USDT" : "TRX"
        let amount = Self.compactAmount(transaction.amount, decimals: transaction.token.fractionDigits)
        let isReceive = walletAddress.map { transaction.getTransactionType(address: $0) == .receive } ?? false
        kind = walletAddress == nil ? .other : isReceive ? .receive : .send
        counterpartyAddress = walletAddress == nil ? nil
            : (isReceive ? transaction.fromAccount : transaction.toAccount).base58
        source = Leg(network: "TRON", currency: transaction.token.symbol, amount: isReceive ? nil : amount)
        destination = Leg(network: "TRON", currency: transaction.token.symbol, amount: isReceive ? amount : nil)
        isSpam = false
        historyEntry = .tron(transaction)
    }

    init(
        trading: PerpsPendingTradingAction,
        marketSymbol: String? = nil,
        status: Status = .pending
    ) {
        id = "perps-trading:\(trading.operationId.lowercased())"
        matchingIds = [id]
        transactionIds = [id]
        isExchange = false
        date = Date(timeIntervalSince1970: TimeInterval(trading.createdAtMillis) / 1000)
        self.status = status
        let side = MultichainPerpsSide(rawValue: trading.side.rawValue)
        stage = nil
        title = switch trading.payload {
        case .open: Self.title(status, .perpsOpened(side))
        case .close: Self.title(status, .perpsClosed(side))
        case .sizeChange, .marginChange, .autoCloseChange, .limitOrderChange: Self.title(status, nil)
        }
        chain = "PERPS"
        detail = marketSymbol
        source = nil
        let amount: String?
        if case .open = trading.payload,
           let size = trading.expectedBaseSize, size.isFinite, size > 0
        {
            amount = AmountFormatter().format(decimal: Decimal(size), style: .compact)
        } else {
            amount = nil
        }
        destination = Leg(network: "PERPS", currency: marketSymbol, amount: amount)
        kind = .other
        counterpartyAddress = nil
        isSpam = false
        historyEntry = nil
        perpsMarketId = trading.marketId
    }

    init(funding: PerpsPendingFundingOperation) {
        id = TransactionLiveActivityLink.perpsFundingPrefix + funding.operationId.lowercased()
        matchingIds = [id]
        transactionIds = [id]
        isExchange = false
        date = Date(timeIntervalSince1970: TimeInterval(funding.createdAtMillis) / 1000)
        chain = "PERPS"
        detail = nil
        if let deposit = funding.deposit {
            source = Leg(
                network: MultichainChain(assetId: deposit.sourceAsset.assetId)?.rawValue.uppercased(),
                currency: deposit.sourceAsset.symbol,
                amount: Self.compactAmount(deposit.sourceAmountUnits, decimals: deposit.sourceAsset.decimals)
            )
            destination = Leg(
                network: MultichainChain(assetId: deposit.targetAsset.assetId)?.rawValue.uppercased(),
                currency: deposit.targetAsset.symbol,
                amount: Self.compactDeclaredAmount(deposit.creditedAmount)
            )
        } else if let withdraw = funding.withdraw {
            source = Leg(
                network: "PERPS",
                currency: "USDC",
                amount: Self.compactAmount(withdraw.amountUnits, decimals: 6)
            )
            destination = Leg(network: withdraw.chainId == 1 ? "ETH" : nil, currency: "USDC", amount: nil)
        } else {
            source = nil
            destination = nil
        }
        kind = .other
        counterpartyAddress = nil
        isSpam = false
        historyEntry = nil
        if funding.deposit?.stage == .credited || funding.withdraw?.stage == .settled {
            status = .confirmed
        } else if funding.deposit?.stage == .failed || funding.deposit?.stage == .refunded
            || funding.withdraw?.stage == .rejected
        {
            status = .failed
        } else if funding.isStalled {
            status = .unknown
        } else {
            status = .pending
        }
        let staged = status == .pending ? Self.fundingStage(funding) : nil
        stage = staged?.stage
        title = staged?.title ?? Self.title(status, funding.kind == .deposit ? .perpsDeposit : .perpsWithdrawal)
    }

    /// The ring moves on every stage the journal records; the title names only the few a person tells apart.
    private static func fundingStage(_ funding: PerpsPendingFundingOperation) -> (stage: Stage, title: String)? {
        if let deposit = funding.deposit {
            let isConverted = deposit.route == .crosschainSwap
            let sending = TKLocales.LiveActivity.Stage.sendingFromWallet
            // The backend reports a sent deposit only as pending: for a converted one that wait is the conversion.
            let arriving: String
            if isConverted {
                let target = deposit.targetAsset
                arriving = target.symbol == deposit.sourceAsset.symbol
                    ? TKLocales.LiveActivity.Stage.movingTo(
                        MultichainChain(assetId: target.assetId)?.rawValue.uppercased() ?? target.symbol
                    )
                    : TKLocales.LiveActivity.Stage.convertingTo(target.symbol)
            } else {
                arriving = TKLocales.LiveActivity.Stage.creditingToPerps
            }
            let step: (index: Int, title: String)? = switch deposit.stage {
            case .sourcePending, .sourceSigned, .sourceSending, .sourceUnknown:
                (1, sending)
            case .awaitingDelivery, .readyForGateway, .approvalPending, .gatewaySigned, .gatewaySending,
                 .gatewayUnknown:
                isConverted ? (2, arriving) : (1, sending)
            case .registrationPending, .needsAuthorization:
                (2, arriving)
            case .registeredPending:
                (3, arriving)
            case .draft, .preparing, .credited, .unconfirmed, .failed, .refunded:
                nil
            }
            return step.map { (Stage(index: $0.index, count: 4), $0.title) }
        }
        let step: (index: Int, title: String)? = switch funding.withdraw?.stage {
        case .signed:
            (1, TKLocales.LiveActivity.Stage.sendingRequest)
        case .sending, .unknown:
            (2, TKLocales.LiveActivity.Stage.sendingRequest)
        case .accepted:
            (3, TKLocales.LiveActivity.Stage.processingWithdrawal)
        case .awaitingL1:
            (4, TKLocales.LiveActivity.Stage.sendingToWallet)
        case .reviewed, .settled, .unconfirmed, .rejected, nil:
            nil
        }
        return step.map { (Stage(index: $0.index, count: 5), $0.title) }
    }

    /// Until its destination transaction shows up a cross-chain exchange is on its way there; then it arrives.
    /// The ring also moves once the history knows the source transaction.
    private static func crossChainStage(
        to chain: MultichainChain,
        currency: String?,
        isIndexed: Bool,
        isArriving: Bool
    ) -> (stage: Stage, title: String) {
        let network = chain.rawValue.uppercased()
        return isArriving
            ? (Stage(index: 3, count: 4), TKLocales.LiveActivity.Stage.receiving(currency ?? network))
            : (Stage(index: isIndexed ? 2 : 1, count: 4), TKLocales.LiveActivity.Stage.movingTo(network))
    }

    /// Every kind names its own outcome: "Sending" ends as "Sent", "Opening long" as "Long opened".
    static func title(_ status: Status, _ presentation: MultichainActivityPresentationKind?) -> String {
        switch status {
        case .pending:
            switch presentation {
            case .perpsDeposit: TKLocales.LiveActivity.depositing
            case .perpsWithdrawal: TKLocales.LiveActivity.withdrawing
            case .perpsOpened(.long): TKLocales.LiveActivity.openingLong
            case .perpsOpened(.short): TKLocales.LiveActivity.openingShort
            case .perpsClosed(.long): TKLocales.LiveActivity.closingLong
            case .perpsClosed(.short): TKLocales.LiveActivity.closingShort
            case .perpsOpened(nil), .perpsClosed(nil), .perpsIncreased, .perpsReduced, .perpsLiquidated,
                 .perpsTakeProfit, .perpsStopLoss, nil:
                TKLocales.ActionTypes.pending
            case let presentation?: presentation.pendingTitle
            }
        case .confirmed:
            switch presentation {
            case .swap: TKLocales.LiveActivity.swapped
            case .perpsDeposit: TKLocales.LiveActivity.deposited
            case .perpsWithdrawal: TKLocales.LiveActivity.withdrawn
            case let presentation?: presentation.title
            case nil: TKLocales.Result.success
            }
        case .failed: TKLocales.State.failed
        case .dropped: TKLocales.LiveActivity.dropped
        case .unknown: TKLocales.LiveActivity.statusMayHaveChanged
        }
    }

    private static func tonLegs(_ action: AccountEventAction, isIncoming: Bool) -> (Leg, Leg)? {
        switch action.type {
        case let .tonTransfer(transfer):
            let amount = compactAmount(BigUInt(transfer.amount.magnitude), decimals: 9)
            return (
                Leg(network: "TON", currency: "TON", amount: isIncoming ? nil : amount),
                Leg(network: "TON", currency: "TON", amount: isIncoming ? amount : nil)
            )
        case let .jettonTransfer(transfer):
            let token = transfer.jettonInfo
            let formatted = compactAmount(token.scaledAmount(transfer.amount), decimals: token.fractionDigits)
            return (
                Leg(network: "TON", currency: token.symbol, amount: isIncoming ? nil : formatted),
                Leg(network: "TON", currency: token.symbol, amount: isIncoming ? formatted : nil)
            )
        case let .jettonSwap(swap):
            let sent: (String?, String?)?
            if let tonIn = swap.tonIn {
                sent = ("TON", compactAmount(BigUInt(tonIn.magnitude), decimals: 9))
            } else if let token = swap.jettonInfoIn {
                sent = (token.symbol, compactAmount(token.scaledAmount(swap.amountIn), decimals: token.fractionDigits))
            } else {
                sent = nil
            }
            let received: (String?, String?)?
            if let tonOut = swap.tonOut {
                received = ("TON", compactAmount(BigUInt(tonOut.magnitude), decimals: 9))
            } else if let token = swap.jettonInfoOut {
                received = (token.symbol, compactAmount(token.scaledAmount(swap.amountOut), decimals: token.fractionDigits))
            } else {
                received = nil
            }
            return (
                Leg(network: "TON", currency: sent?.0, amount: sent?.1),
                Leg(network: "TON", currency: received?.0, amount: received?.1)
            )
        default:
            return nil
        }
    }

    private static func compactAmount(_ raw: String?, decimals: Int?) -> String? {
        guard let raw, let decimals else { return nil }
        if let amount = BigUInt(raw) {
            return compactAmount(amount, decimals: decimals)
        }
        return raw.contains(".") ? compactDeclaredAmount(raw) : nil
    }

    private static func compactAmount(_ amount: BigUInt, decimals: Int?) -> String? {
        guard let decimals else { return nil }
        return AmountFormatter().format(amount: amount, fractionDigits: decimals, style: .compact)
    }

    private static func compactDeclaredAmount(_ raw: String?) -> String? {
        guard let raw, let amount = Decimal(string: raw, locale: Locale(identifier: "en_US_POSIX")) else {
            return nil
        }
        return AmountFormatter().format(decimal: amount, style: .compact)
    }

    private static func normalizedId(_ raw: String, chain: MultichainChain?) -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let separator = value.firstIndex(of: ":"),
           let prefix = MultichainChain(assetIdChain: String(value[..<separator]))
        {
            return prefix.rawValue + value[separator...]
        }
        return "\(chain?.rawValue ?? "multichain"):\(value)"
    }
}

@available(iOS 16.2, *)
enum TransactionLiveActivitySelection {
    static let exchangePrefix = "swap:"
    static let startWindow: TimeInterval = 8 * 60 * 60
    /// A message that never lands leaves nothing in history to end its activity by, so a pending one
    /// that complete refreshes stop finding is given up after this long.
    static let unseenLimit: TimeInterval = 10 * 60

    enum Outcome {
        /// Already on the activity, from a refresh that left the rest to a later one.
        case shown
        case reached(TransactionLiveActivitySnapshot)
        case unknown
    }

    enum Step {
        case stay
        case follow(TransactionLiveActivitySnapshot)
        case replace(by: TransactionLiveActivitySnapshot)
        case settle(Outcome, next: TransactionLiveActivitySnapshot?)
    }

    /// What the one activity does with what a refresh found. A newer transaction takes it over at once,
    /// an older one waits until the current one settles.
    static func step(
        tracking id: String,
        status: TransactionLiveActivitySnapshot.Status,
        updatedAt: Date,
        in snapshots: [TransactionLiveActivitySnapshot],
        next candidate: TransactionLiveActivitySnapshot?,
        perpsLoaded: Bool,
        judgesAbsence: Bool,
        now: Date = Date()
    ) -> Step {
        guard status == .pending else { return .settle(.shown, next: candidate) }
        if let snapshot = matching(id, in: snapshots) {
            guard snapshot.status == .pending else { return .settle(.reached(snapshot), next: candidate) }
            if let candidate, candidate.date > snapshot.date { return .replace(by: candidate) }
            return .follow(snapshot)
        }
        if id.hasPrefix("perps-"), perpsLoaded { return .settle(.unknown, next: candidate) }
        // A missing item may have moved beyond the fetched page; a short absence is not a verdict.
        guard judgesAbsence else { return .stay }
        // A newer transaction must not wait on one that may never show up again.
        if let candidate { return .replace(by: candidate) }
        return now.timeIntervalSince(updatedAt) > unseenLimit ? .settle(.unknown, next: nil) : .stay
    }

    /// An activity started for a plain transfer that has since turned out to be the leg of a swap or a
    /// bridge follows the exchange, whose outcome is the operation's.
    static func matching(
        _ id: String,
        in snapshots: [TransactionLiveActivitySnapshot]
    ) -> TransactionLiveActivitySnapshot? {
        let id = id.lowercased()
        let exchanges = id.hasPrefix(exchangePrefix)
            ? [] : snapshots.filter { $0.isExchange && $0.transactionIds.contains(id) }
        let matches = exchanges.isEmpty ? snapshots.filter { $0.matchingIds.contains(id) } : exchanges
        return matches.first(where: { $0.status != .pending }) ?? matches.first
    }

    static func nextPending(
        in snapshots: [TransactionLiveActivitySnapshot],
        excluding startedIds: Set<String> = [],
        walletId: String = ""
    ) -> TransactionLiveActivitySnapshot? {
        let earliestStart = Date().addingTimeInterval(-startWindow)
        let terminalIds = Set(snapshots.filter { $0.status != .pending }.flatMap(\.matchingIds))
        // The leg of a known exchange is shown as the exchange, never as a transfer of its own.
        let exchangeLegs = Set(snapshots.filter(\.isExchange).flatMap(\.transactionIds))
        return snapshots
            .filter {
                $0.status == .pending && $0.date >= earliestStart && !$0.isSpam
                    && $0.matchingIds.isDisjoint(with: terminalIds)
                    && ($0.isExchange || $0.transactionIds.isDisjoint(with: exchangeLegs))
                    && !$0.matchingIds.contains { startedIds.contains("\(walletId):\($0)") }
            }
            .max(by: { $0.date < $1.date })
    }

    static func chain(of id: String) -> String? {
        let id = id.lowercased()
        let transactionId = id.hasPrefix(exchangePrefix) ? String(id.dropFirst(exchangePrefix.count)) : id
        return transactionId.split(separator: ":", maxSplits: 1).first.map(String.init)
    }
}

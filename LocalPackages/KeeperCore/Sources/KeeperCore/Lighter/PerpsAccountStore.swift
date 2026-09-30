import ChainKit
import Foundation
import TKLogging

public enum PerpsMarketLifecycle: Equatable {
    case flat
    case opening(PerpsOpeningDescriptor)
    case open(PerpsPositionSummary)
    case closing(PerpsPositionSummary)
    case adjusting(PerpsPositionSummary, PerpsSizeChangeDirection)
    case adjustingMargin(PerpsPositionSummary, PerpsMarginChangeDirection, amountUsd: Double)
}

public struct PerpsOpeningDescriptor: Equatable, Sendable {
    public let marketId: Int64
    public let symbol: String
    public let side: PerpsTradeSide
    public let marginUsd: Double
    public let leverage: Double
    public let isLimit: Bool

    public init(marketId: Int64, symbol: String, side: PerpsTradeSide, marginUsd: Double, leverage: Double, isLimit: Bool) {
        self.marketId = marketId
        self.symbol = symbol
        self.side = side
        self.marginUsd = marginUsd
        self.leverage = leverage
        self.isLimit = isLimit
    }
}

public final class PerpsAccountStore: Store<PerpsAccountStore.Event, PerpsAccountStore.State>, @unchecked Sendable {
    public enum State {
        case unresolved
        case resolving
        case unbound
        case inactive
        case active(Account)

        public struct Account {
            public let accountIndex: Int64
            public let availableBalance: String
            public let positions: [PerpsPositionSummary]

            public init(accountIndex: Int64, availableBalance: String, positions: [PerpsPositionSummary] = []) {
                self.accountIndex = accountIndex
                self.availableBalance = availableBalance
                self.positions = positions
            }
        }
    }

    public enum Event {
        case didUpdate(State)
    }

    private struct Pending {
        enum Kind: Equatable {
            case opening(PerpsOpeningDescriptor)
            case closing(PerpsTradeSide, baseSizeBefore: Double)
            case adjusting(PerpsSizeChangeDirection, baseSizeBefore: Double)
            case adjustingMargin(PerpsMarginChangeDirection, allocatedMarginBefore: Double, amountUsd: Double)
        }

        let kind: Kind
    }

    private var pendingByMarket: [Int64: Pending] = [:]

    private var requestedExtrasMarkets: Set<Int64> = []
    private var marketExtrasByMarket: [Int64: (accountIndex: Int64, extras: PerpsMarketExtras)] = [:]
    private var marketExtrasRequestIds: [Int64: UUID] = [:]
    private var lastPositionedMarkets: Set<Int64> = []
    private var didSeedPositionedMarkets = false

    private let positionsLifecycleLock = NSLock()
    private var positionsSubscriberCount = 0
    private var positionsWatch: PerpsPositionsWatch?
    private var positionsFlushTask: Task<Void, Never>?
    private var positionsStopItem: DispatchWorkItem?
    private var positionsStopToken: UUID?
    private let pendingPositionsLock = NSLock()
    private nonisolated(unsafe) var pendingPositions: [PerpsPositionSummary]?

    private let operationRecoveryLock = NSLock()
    private var operationRecoveryGeneration: UUID?
    private var operationRecoveryTask: Task<Void, Never>?
    private var operationRecoveryRetryTask: Task<Void, Never>?
    private var operationRecoveryRequested = false

    private let service: PerpsAccountReading
    private let wallet: Wallet
    private let recoverOperations: @Sendable () async -> Void

    private let lock = NSLock()
    private var isResolved = false
    private var isResolving = false
    private var resolveTask: Task<Void, Never>?

    init(
        service: PerpsAccountReading,
        wallet: Wallet,
        recoverOperations: @escaping @Sendable () async -> Void = {}
    ) {
        self.service = service
        self.wallet = wallet
        self.recoverOperations = recoverOperations
        super.init(state: .unresolved)
    }

    deinit {
        stopOperationRecovery()
        stopPositionsWatch()
    }

    override public func createInitialState() -> State {
        .unresolved
    }

    public func currentWalletState() -> State {
        lock.lock()
        let isResolved = isResolved
        lock.unlock()
        return isResolved ? getState() : .unresolved
    }

    public func resolveIfNeeded() {
        lock.lock()
        let settled = isResolved || isResolving
        lock.unlock()
        guard !settled else { return }
        resolve(showResolving: true)
    }

    public func refresh() {
        resolve(showResolving: false)
    }

    // MARK: - Trade lifecycle

    public func lifecycle(marketId: Int64) -> PerpsMarketLifecycle {
        let position = matchingPosition(marketId: marketId)
        let pending = lock.withLock { pendingByMarket[marketId] }
        if let pending {
            switch pending.kind {
            case let .opening(descriptor):
                return position.map(PerpsMarketLifecycle.open) ?? .opening(descriptor)
            case .closing:
                return position.map(PerpsMarketLifecycle.closing) ?? .flat
            case let .adjusting(direction, _):
                return position.map { .adjusting($0, direction) } ?? .flat
            case let .adjustingMargin(direction, _, amountUsd):
                return position.map { .adjustingMargin($0, direction, amountUsd: amountUsd) } ?? .flat
            }
        }
        return position.map(PerpsMarketLifecycle.open) ?? .flat
    }

    public func matchingPosition(marketId: Int64) -> PerpsPositionSummary? {
        guard case let .active(account) = currentWalletState() else { return nil }
        return account.positions.first { $0.marketId == marketId }
    }

    public func beginOpening(_ descriptor: PerpsOpeningDescriptor) {
        lock.withLock { pendingByMarket[descriptor.marketId] = Pending(kind: .opening(descriptor)) }
        notifyLifecycleChanged()
    }

    public func beginClosing(marketId: Int64) {
        guard let position = matchingPosition(marketId: marketId) else { return }
        lock.withLock {
            pendingByMarket[marketId] = Pending(
                kind: .closing(position.side, baseSizeBefore: position.baseSize)
            )
        }
        notifyLifecycleChanged()
    }

    /// `baseSizeBefore` must be the prepare-time venue read (the baseline the
    /// size-change reconciliation confirms against) — the live stream may already
    /// differ by the time the user swipes.
    public func beginAdjusting(marketId: Int64, direction: PerpsSizeChangeDirection, baseSizeBefore: Double) {
        lock.withLock {
            pendingByMarket[marketId] = Pending(
                kind: .adjusting(direction, baseSizeBefore: baseSizeBefore)
            )
        }
        notifyLifecycleChanged()
    }

    /// `allocatedMarginBefore` must be the prepare-time venue read (the baseline the
    /// margin-change reconciliation confirms against) — the live stream may already
    /// differ by the time the user swipes.
    public func beginAdjustingMargin(
        marketId: Int64,
        direction: PerpsMarginChangeDirection,
        allocatedMarginBefore: Double,
        amountUsd: Double
    ) {
        lock.withLock {
            pendingByMarket[marketId] = Pending(
                kind: .adjustingMargin(direction, allocatedMarginBefore: allocatedMarginBefore, amountUsd: amountUsd)
            )
        }
        notifyLifecycleChanged()
    }

    public func clearPending(marketId: Int64) {
        let changed = lock.withLock { pendingByMarket.removeValue(forKey: marketId) != nil }
        if changed { notifyLifecycleChanged() }
    }

    // MARK: - Per-market extras (TP/SL orders + recent activity)

    public func marketExtras(marketId: Int64) -> PerpsMarketExtras? {
        guard case let .active(account) = currentWalletState() else { return nil }
        return lock.withLock {
            guard let entry = marketExtrasByMarket[marketId],
                  entry.accountIndex == account.accountIndex
            else { return nil }
            return entry.extras
        }
    }

    public func loadMarketExtras(marketId: Int64) {
        lock.withLock { _ = requestedExtrasMarkets.insert(marketId) }
        guard case let .active(account) = currentWalletState() else { return }
        fetchMarketExtras(accountIndex: account.accountIndex, marketId: marketId)
    }

    public func releaseMarketExtras(marketId: Int64) {
        lock.withLock { _ = requestedExtrasMarkets.remove(marketId) }
    }

    // MARK: - Live positions stream

    public func subscribePositions() {
        positionsLifecycleLock.withLock {
            positionsStopItem?.cancel()
            positionsStopItem = nil
            positionsStopToken = nil
            positionsSubscriberCount += 1
        }
        startPositionsWatchIfNeeded()
    }

    public func unsubscribePositions() {
        let isLast = positionsLifecycleLock.withLock {
            positionsSubscriberCount = max(0, positionsSubscriberCount - 1)
            return positionsSubscriberCount == 0
        }
        if isLast { schedulePositionsStop() }
    }
}

private extension PerpsAccountStore {
    func resolve(showResolving: Bool) {
        if showResolving {
            stopOperationRecovery()
            stopPositionsWatch()
            setState(.resolving)
        }
        lock.withLock {
            resolveTask?.cancel()
            isResolving = true
            if showResolving { isResolved = false }
            resolveTask = Task { [weak self] in
                guard let self else { return }
                let status = await service.status(wallet: wallet)
                guard !Task.isCancelled else { return }
                switch status {
                case let .account(accountIndex):
                    await applyActive(accountIndex: accountIndex)
                case .unbound:
                    setResolved(state: .unbound)
                case .noAccount, .unknown:
                    setResolved(state: .inactive)
                case let .unavailable(reason):
                    Log.w("🪵 Perps: status probe failed — \(reason)")
                    finishUnresolved()
                }
            }
        }
    }

    func applyActive(accountIndex: Int64) async {
        do {
            guard let portfolio = try await service.portfolio(wallet: wallet) else {
                guard !Task.isCancelled else { return }
                Log.w("🪵 Perps: portfolio read returned nil")
                finishUnresolved()
                return
            }
            guard !Task.isCancelled else { return }
            let positions = portfolio.positions
            reconcilePending(positions: positions)
            setResolved(state: .active(.init(
                accountIndex: accountIndex,
                availableBalance: portfolio.availableBalance,
                positions: positions
            )))
            reloadRequestedExtras(accountIndex: accountIndex)
            guard !Task.isCancelled else { return }
            startOperationRecovery()
            startPositionsWatch()
        } catch {
            guard !Task.isCancelled else { return }
            Log.w("🪵 Perps: portfolio read failed — \(error)")
            finishUnresolved()
        }
    }

    func setResolved(state: State) {
        setState(state, markResolved: true)
        if case .active = state {} else {
            stopOperationRecovery()
            stopPositionsWatch()
        }
    }

    func finishUnresolved() {
        let hasResolvedState = lock.withLock {
            isResolving = false
            resolveTask = nil
            return isResolved
        }
        if !hasResolvedState {
            setState(.unresolved)
            stopOperationRecovery()
            stopPositionsWatch()
        }
    }

    func reconcilePending(positions: [PerpsPositionSummary]) {
        let positionsByMarket = Dictionary(positions.map { ($0.marketId, $0) }, uniquingKeysWith: { first, _ in first })
        lock.withLock {
            pendingByMarket = pendingByMarket.filter { marketId, pending in
                switch pending.kind {
                case .opening: return positionsByMarket[marketId] == nil
                case let .closing(side, baseSizeBefore):
                    guard let position = positionsByMarket[marketId] else { return false }
                    return position.side == side && !PerpsChangeSettlement.closeMoved(
                        current: position.baseSize,
                        before: baseSizeBefore
                    )
                case let .adjusting(direction, baseSizeBefore):
                    guard let position = positionsByMarket[marketId] else { return false }
                    return !PerpsChangeSettlement.sizeMoved(
                        current: position.baseSize,
                        before: baseSizeBefore,
                        direction: direction
                    )
                case let .adjustingMargin(direction, allocatedMarginBefore, amountUsd):
                    guard let position = positionsByMarket[marketId] else { return false }
                    return !PerpsChangeSettlement.marginMoved(
                        current: position.marginUsd,
                        before: allocatedMarginBefore,
                        amountUsd: amountUsd,
                        direction: direction
                    )
                }
            }
        }
    }

    func notifyLifecycleChanged() {
        setStateNotifying(getState(), event: Event.didUpdate)
    }

    func reloadRequestedExtras(accountIndex: Int64) {
        let markets = lock.withLock { Array(requestedExtrasMarkets) }
        for marketId in markets {
            fetchMarketExtras(accountIndex: accountIndex, marketId: marketId)
        }
    }

    func fetchMarketExtras(accountIndex: Int64, marketId: Int64) {
        let requestId = UUID()
        lock.withLock {
            marketExtrasRequestIds[marketId] = requestId
        }
        Task { [weak self] in
            guard let self else { return }
            async let trading = self.tradingSnapshotResult(accountIndex: accountIndex, marketId: marketId)
            async let activity = self.recentActivityResult(accountIndex: accountIndex, marketId: marketId, limit: 3)
            let (tradingResult, activityResult) = await(trading, activity)
            if case let .failure(error) = tradingResult {
                Log.w("🪵 Perps: trading-screen fetch failed market=\(marketId) — \(error)")
            }
            if case let .failure(error) = activityResult {
                Log.w("🪵 Perps: recent-activity fetch failed market=\(marketId) — \(error)")
            }
            // Nothing fresh — don't churn the cache so a fully offline refresh keeps last-known extras.
            if case .failure = tradingResult, case .failure = activityResult {
                self.finishMarketExtrasFetch(marketId: marketId, requestId: requestId)
                return
            }
            // Each side falls back to last-known on failure rather than blanking live
            // order rows or history, while a successful side always lands.
            let cached = self.cachedExtras(marketId: marketId, accountIndex: accountIndex)
            let tradingSnapshot = try? tradingResult.get()
            let activeOrders = tradingSnapshot?.orders
            let limitOrders = activeOrders?.limitOrders ?? cached?.limitOrders ?? []
            let triggerOrders = activeOrders?.triggerOrders ?? cached?.triggerOrders ?? []
            let recentActivity = (try? activityResult.get()) ?? cached?.recentActivity ?? []
            let extras = PerpsMarketExtras(
                limitOrders: limitOrders,
                triggerOrders: triggerOrders,
                recentActivity: recentActivity,
                flags: tradingSnapshot?.flags ?? cached?.flags,
                autoCloseKnown: tradingSnapshot.map { $0.orders != nil } ?? (cached?.autoCloseKnown ?? false)
            )
            let stored = self.lock.withLock { () -> Bool in
                guard self.marketExtrasRequestIds[marketId] == requestId else { return false }
                self.marketExtrasRequestIds[marketId] = nil
                self.marketExtrasByMarket[marketId] = (accountIndex, extras)
                return true
            }
            if stored { self.notifyLifecycleChanged() }
        }
    }

    private func cachedExtras(marketId: Int64, accountIndex: Int64) -> PerpsMarketExtras? {
        lock.withLock {
            guard let entry = marketExtrasByMarket[marketId],
                  entry.accountIndex == accountIndex
            else { return nil }
            return entry.extras
        }
    }

    func tradingSnapshotResult(
        accountIndex: Int64,
        marketId: Int64
    ) async -> Result<PerpsTradingSnapshot, Error> {
        do {
            return try .success(await service.tradingSnapshot(
                wallet: wallet,
                marketId: marketId,
                positionId: matchingPosition(marketId: marketId)?.positionId
            ))
        } catch {
            return .failure(error)
        }
    }

    func recentActivityResult(
        accountIndex: Int64,
        marketId: Int64,
        limit: Int
    ) async -> Result<[PerpsActivityItem], Error> {
        do {
            return try .success(await service.recentActivity(wallet: wallet, marketId: marketId, limit: limit))
        } catch {
            return .failure(error)
        }
    }

    func finishMarketExtrasFetch(marketId: Int64, requestId: UUID) {
        lock.withLock {
            if marketExtrasRequestIds[marketId] == requestId {
                marketExtrasRequestIds[marketId] = nil
            }
        }
    }

    // MARK: - Operation recovery

    func startOperationRecovery() {
        let generation = operationRecoveryLock.withLock { () -> UUID in
            let generation = operationRecoveryGeneration ?? UUID()
            operationRecoveryGeneration = generation
            return generation
        }
        scheduleOperationRecovery(generation: generation)
        let shouldStartRetry = operationRecoveryLock.withLock {
            operationRecoveryRetryTask == nil && operationRecoveryGeneration == generation
        }
        guard shouldStartRetry else { return }
        let retryTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard !Task.isCancelled else { return }
                self?.scheduleOperationRecovery(generation: generation)
            }
        }
        operationRecoveryLock.withLock {
            guard operationRecoveryGeneration == generation, operationRecoveryRetryTask == nil else {
                retryTask.cancel()
                return
            }
            operationRecoveryRetryTask = retryTask
        }
    }

    func scheduleOperationRecovery(generation: UUID) {
        operationRecoveryLock.withLock {
            guard operationRecoveryGeneration == generation else { return }
            operationRecoveryRequested = true
            guard operationRecoveryTask == nil else { return }
            operationRecoveryTask = Task { [weak self] in
                await self?.drainOperationRecovery(generation: generation)
            }
        }
    }

    func drainOperationRecovery(generation: UUID) async {
        while !Task.isCancelled {
            let shouldRecover = operationRecoveryLock.withLock {
                guard operationRecoveryGeneration == generation else {
                    return false
                }
                guard operationRecoveryRequested else {
                    operationRecoveryTask = nil
                    return false
                }
                operationRecoveryRequested = false
                return true
            }
            guard shouldRecover else { return }
            await recoverOperations()
        }
    }

    func stopOperationRecovery() {
        let recoveryTasks = operationRecoveryLock.withLock { () -> (Task<Void, Never>?, Task<Void, Never>?) in
            let task = operationRecoveryTask
            let retryTask = operationRecoveryRetryTask
            operationRecoveryGeneration = nil
            operationRecoveryTask = nil
            operationRecoveryRetryTask = nil
            operationRecoveryRequested = false
            return (task, retryTask)
        }
        recoveryTasks.0?.cancel()
        recoveryTasks.1?.cancel()
    }

    func startPositionsWatchIfNeeded() {
        guard case .active = currentWalletState() else { return }
        startPositionsWatch()
    }

    func startPositionsWatch() {
        guard positionsLifecycleLock.withLock({ positionsSubscriberCount > 0 && positionsWatch == nil }) else { return }
        let watch = service.watchPositions(
            wallet: wallet,
            onUpdate: { [weak self] positions in
                guard let self else { return }
                self.pendingPositionsLock.withLock { self.pendingPositions = positions }
            },
            onInterrupted: { [weak self] in
                self?.refresh()
            }
        )
        let nextFlush = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                self?.flushPositions()
            }
        }
        let installed = positionsLifecycleLock.withLock { () -> Bool in
            guard positionsSubscriberCount > 0, positionsWatch == nil else { return false }
            positionsWatch = watch
            positionsFlushTask = nextFlush
            return true
        }
        if !installed {
            watch.cancel()
            nextFlush.cancel()
        }
    }

    func stopPositionsWatch() {
        let handles = positionsLifecycleLock.withLock { () -> (PerpsPositionsWatch?, Task<Void, Never>?) in
            let handles = (positionsWatch, positionsFlushTask)
            positionsWatch = nil
            positionsFlushTask = nil
            positionsStopItem = nil
            positionsStopToken = nil
            return handles
        }
        handles.0?.cancel()
        handles.1?.cancel()
        pendingPositionsLock.withLock { pendingPositions = nil }
        lock.withLock {
            lastPositionedMarkets = []
            didSeedPositionedMarkets = false
        }
    }

    func schedulePositionsStop() {
        let token = UUID()
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let shouldStop = self.positionsLifecycleLock.withLock {
                self.positionsSubscriberCount == 0 && self.positionsStopToken == token
            }
            if shouldStop { self.stopPositionsWatch() }
        }
        positionsLifecycleLock.withLock {
            positionsStopToken = token
            positionsStopItem = item
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: item)
    }

    func flushPositions() {
        let positions = pendingPositionsLock.withLock { () -> [PerpsPositionSummary]? in
            let snapshot = pendingPositions
            pendingPositions = nil
            return snapshot
        }
        guard let positions else { return }
        guard case let .active(account) = currentWalletState() else { return }
        // A socket snapshot must not blank an existing position on its own: an empty list
        // during a reconnect blip would flash `.flat` (Long/Short) on a market the user
        // still holds. Defer to an authoritative REST read, which also reflects a genuine
        // full close a beat later.
        if positions.isEmpty, !account.positions.isEmpty {
            refresh()
            return
        }
        reconcilePending(positions: positions)
        setResolved(state: .active(.init(
            accountIndex: account.accountIndex,
            availableBalance: account.availableBalance,
            positions: positions
        )))
        refreshExtrasForPositionFlips(accountIndex: account.accountIndex, positions: positions)
    }

    private func refreshExtrasForPositionFlips(accountIndex: Int64, positions: [PerpsPositionSummary]) {
        let openMarkets = Set(positions.map(\.marketId))
        let toRefresh: [Int64] = lock.withLock {
            defer { lastPositionedMarkets = openMarkets }
            guard didSeedPositionedMarkets else {
                didSeedPositionedMarkets = true
                return []
            }
            let flipped = openMarkets.symmetricDifference(lastPositionedMarkets)
            return requestedExtrasMarkets.intersection(flipped).sorted()
        }
        for marketId in toRefresh {
            fetchMarketExtras(accountIndex: accountIndex, marketId: marketId)
        }
    }

    func setState(_ newState: State, markResolved: Bool = false) {
        setStateNotifying(newState, event: Event.didUpdate) { [weak self] _ in
            guard let self, markResolved else { return }
            self.lock.withLock {
                self.isResolved = true
                self.isResolving = false
                self.resolveTask = nil
            }
        }
    }
}

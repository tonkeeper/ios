import ChainKit
import Foundation
import PerpsModels
import TKLogging

public final class PerpsAccountStore: Store<PerpsAccountStore.Event, PerpsAccountStore.State>, @unchecked Sendable {
    public typealias State = PerpsWalletAccountState

    @frozen public enum Event {
        case didUpdate(State)
        case didUpdateFunding(PerpsFundingState)
    }

    private struct Pending {
        enum Kind: Equatable {
            case opening(PerpsOpeningDescriptor)
            case closing(PerpsTradeSide, baseSizeBefore: Double)
            case adjusting(PerpsSizeChangeDirection, baseSizeBefore: Double)
            case adjustingMargin(PerpsMarginChangeDirection, allocatedMarginBefore: Double, amountUsd: Double)
        }

        let kind: Kind
        var clearsAfterExtrasReload = false
    }

    private var pendingByMarket: [Int64: Pending] = [:]

    private var requestedExtrasMarkets: Set<Int64> = []
    private var marketExtrasByMarket: [Int64: (accountIndex: Int64, extras: PerpsMarketExtras)] = [:]
    private var marketExtrasRequestIds: [Int64: UUID] = [:]
    struct PositionShape: Equatable {
        let side: PerpsTradeSide
        let baseSize: Double
    }

    private var lastPositionShapes: [Int64: PositionShape] = [:]
    private var didSeedPositionedMarkets = false

    private var positionsController: PerpsPositionsController?

    private let operationRecoveryLock = NSLock()
    private var operationRecoveryGeneration: UUID?
    private var operationRecoveryTask: Task<Void, Never>?
    private var operationRecoveryRetryTask: Task<Void, Never>?
    private var operationRecoveryRequested = false
    private var autoCloseRenewal: (id: UUID, task: Task<Void, Never>)?

    private let service: PerpsAccountReading
    private let wallet: Wallet
    private let recoverOperations: @Sendable () async -> Void
    private let renewAutoClose: @Sendable (_ marketIds: [Int64]) async -> Void
    private let refreshOrderAccess: @Sendable () async -> Bool
    private let reissueReadOnlyToken: @Sendable () async -> Bool
    private let holdsTradingKey: @Sendable () async -> Bool
    private let ensureAccountTier: @Sendable () async -> Void
    private let loadHistory: @Sendable (_ marketId: Int64, _ limit: Int) async throws -> [PerpsHistoryEvent]
    /// A failed resolve leaves the store unresolved and every screen showing nothing, and a
    /// transient failure (a 503 from upstream, a dropped connection) is the usual cause — so it
    /// is retried on this schedule until it settles, a newer resolve supersedes it, or it runs out.
    private let resolveRetryDelays: [TimeInterval]
    private let waitBeforeRetry: @Sendable (TimeInterval) async -> Void

    private let lock = NSLock()
    private var isResolved = false
    private var isResolving = false
    private var resolveTask: Task<Void, Never>?
    private var resolveFailures = 0
    private var fundingState: PerpsFundingState = .unresolved
    private var fundingRefreshId: UUID?

    init(
        service: PerpsAccountReading,
        wallet: Wallet,
        recoverOperations: @escaping @Sendable () async -> Void = {},
        renewAutoClose: @escaping @Sendable (_ marketIds: [Int64]) async -> Void = { _ in },
        refreshOrderAccess: @escaping @Sendable () async -> Bool = { false },
        reissueReadOnlyToken: @escaping @Sendable () async -> Bool = { false },
        holdsTradingKey: @escaping @Sendable () async -> Bool = { true },
        ensureAccountTier: @escaping @Sendable () async -> Void = {},
        loadHistory: @escaping @Sendable (_ marketId: Int64, _ limit: Int) async throws -> [PerpsHistoryEvent] = { _, _ in [] },
        resolveRetryDelays: [TimeInterval] = [2, 5, 10, 20, 30],
        waitBeforeRetry: @escaping @Sendable (TimeInterval) async -> Void = {
            try? await Task.sleep(nanoseconds: UInt64($0 * 1_000_000_000))
        }
    ) {
        self.service = service
        self.wallet = wallet
        self.recoverOperations = recoverOperations
        self.renewAutoClose = renewAutoClose
        self.refreshOrderAccess = refreshOrderAccess
        self.reissueReadOnlyToken = reissueReadOnlyToken
        self.holdsTradingKey = holdsTradingKey
        self.ensureAccountTier = ensureAccountTier
        self.loadHistory = loadHistory
        self.resolveRetryDelays = resolveRetryDelays
        self.waitBeforeRetry = waitBeforeRetry
        super.init(state: .unresolved)
        positionsController = PerpsPositionsController(
            makeWatch: { [weak self] cadence, onUpdate, onInterrupted in
                guard let self else { return PerpsPositionsWatch {} }
                return self.service.watchPositions(
                    wallet: self.wallet,
                    pollInterval: cadence.pollInterval,
                    focus: { [weak self] in self?.watchFocus() ?? .positions },
                    onUpdate: onUpdate,
                    onInterrupted: onInterrupted
                )
            },
            onUpdate: { [weak self] in self?.applyPositionsTick($0) },
            onInterrupted: { [weak self] in self?.refresh() },
            onStop: { [weak self] in
                guard let self else { return }
                self.lock.withLock {
                    self.lastPositionShapes = [:]
                    self.didSeedPositionedMarkets = false
                }
            }
        )
    }

    deinit {
        stopOperationRecovery()
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
        let settled = lock.withLock {
            let settled = isResolved || isResolving
            if !settled { resolveFailures = 0 }
            return settled
        }
        guard !settled else { return }
        resolve(showResolving: true)
    }

    public func refresh() {
        lock.withLock { resolveFailures = 0 }
        resolve(showResolving: false)
    }

    static func needsActivation(hasTradingKey: Bool?, holdsTradingKey: Bool) -> Bool {
        hasTradingKey == false || !holdsTradingKey
    }

    public func currentFundingState() -> PerpsFundingState {
        lock.withLock { fundingState }
    }

    public func fundingActivity() -> PerpsFundingActivity {
        var inFlight: Set<String> = []
        var pending: Set<String> = []
        var completed: Set<String> = []
        var transactions: [String: Set<String>] = [:]
        for operation in currentFundingState().operations {
            let hashes = operation.transactionHashes
            if !hashes.isEmpty { transactions[operation.operationId] = hashes }
            if let stage = operation.deposit?.stage {
                if stage.isInFlight { inFlight.insert(operation.operationId) }
                if stage == .credited { completed.insert(operation.operationId) }
            } else if let stage = operation.withdraw?.stage {
                if stage == .signed || stage == .sending || stage == .unknown { inFlight.insert(operation.operationId) }
                if stage == .accepted || stage == .awaitingL1 { pending.insert(operation.operationId) }
                if stage == .settled { completed.insert(operation.operationId) }
            }
        }
        return PerpsFundingActivity(inFlight: inFlight, pending: pending, completed: completed, transactions: transactions)
    }

    func applyFundingState(_ state: PerpsFundingState) {
        let (changed, needsRefresh) = lock.withLock {
            let previous = fundingState
            guard previous != state else { return (false, false) }
            fundingState = state
            let oldOperations = Dictionary(
                previous.operations.map { ($0.operationId, $0) },
                uniquingKeysWith: { first, _ in first }
            )
            let needsRefresh = state.operations.contains { operation in
                let old = oldOperations[operation.operationId]
                if let deposit = operation.deposit {
                    return (deposit.accountIndex != nil && deposit.accountIndex != old?.deposit?.accountIndex)
                        || (deposit.stage == .credited && old?.deposit?.stage != .credited)
                }
                // Lighter debits the balance once it accepts the withdrawal, not when it settles.
                if let withdraw = operation.withdraw {
                    return (withdraw.stage.debitsBalance && old?.withdraw?.stage.debitsBalance != true)
                        || (withdraw.stage == .rejected && old?.withdraw?.stage != .rejected)
                }
                return false
            }
            if needsRefresh { fundingRefreshId = UUID() }
            return (true, needsRefresh)
        }
        if changed { sendEvent(.didUpdateFunding(state)) }
        if needsRefresh { refresh() }
    }

    func retryFundingRefreshIfNeeded() {
        guard lock.withLock({ fundingRefreshId != nil }) else { return }
        refresh()
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
        Log.perps.i("overlay opening \(descriptor)")
        lock.withLock { pendingByMarket[descriptor.marketId] = Pending(kind: .opening(descriptor)) }
        notifyLifecycleChanged()
    }

    public func beginClosing(marketId: Int64) {
        guard let position = matchingPosition(marketId: marketId) else { return }
        Log.perps.i("overlay closing market=\(marketId) side=\(position.side) base=\(position.baseSize)")
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
        Log.perps.i("overlay adjusting market=\(marketId) \(direction) baseBefore=\(baseSizeBefore)")
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
        Log.perps.i("overlay adjustingMargin market=\(marketId) \(direction) before=\(allocatedMarginBefore) amount=\(amountUsd)")
        lock.withLock {
            pendingByMarket[marketId] = Pending(
                kind: .adjustingMargin(direction, allocatedMarginBefore: allocatedMarginBefore, amountUsd: amountUsd)
            )
        }
        notifyLifecycleChanged()
    }

    public func clearPending(marketId: Int64) {
        guard let cleared = lock.withLock({ pendingByMarket.removeValue(forKey: marketId) }) else { return }
        Log.perps.i("overlay cleared market=\(marketId) was=\(cleared.kind)")
        notifyLifecycleChanged()
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

    public func loadMarketExtras(marketId: Int64, clearingPending: Bool = false) {
        lock.withLock { _ = requestedExtrasMarkets.insert(marketId) }
        guard case let .active(account) = currentWalletState() else {
            if clearingPending { clearPending(marketId: marketId) }
            return
        }
        fetchMarketExtras(accountIndex: account.accountIndex, marketId: marketId, clearingPending: clearingPending)
    }

    public func releaseMarketExtras(marketId: Int64) {
        lock.withLock {
            requestedExtrasMarkets.remove(marketId)
            if pendingByMarket[marketId]?.clearsAfterExtrasReload != true {
                marketExtrasRequestIds[marketId] = nil
            }
        }
    }

    // MARK: - Live positions stream

    public func subscribePositions(cadence: PerpsPositionsCadence = .live) {
        positionsController?.subscribe(cadence: cadence)
    }

    public func unsubscribePositions(cadence: PerpsPositionsCadence = .live) {
        positionsController?.unsubscribe(cadence: cadence)
    }
}

private extension PerpsAccountStore {
    func resolve(showResolving: Bool) {
        if showResolving {
            stopOperationRecovery()
            // Published before the stop round-trip rather than after it: a resolve cancelled while
            // waiting would otherwise leave the store unresolved with the previous state on screen.
            // Applying a tick already requires `.active`, so a late one is a no-op either way.
            setState(.resolving)
        }
        lock.withLock {
            resolveTask?.cancel()
            isResolving = true
            if showResolving { isResolved = false }
            resolveTask = Task { [weak self] in
                guard let self else { return }
                if showResolving {
                    await positionsController?.stop()
                    guard !Task.isCancelled else { return }
                }
                // Retries stay inside this task, so a newer resolve cancels them together with it
                // and a retry never replaces anything.
                while await attemptResolve(), await waitToRetry() {}
            }
        }
    }

    /// Returns whether the attempt left the account unresolved, i.e. whether it is worth retrying.
    func attemptResolve() async -> Bool {
        let fundingRefreshId = lock.withLock { self.fundingRefreshId }
        let status = await service.status(wallet: wallet)
        guard !Task.isCancelled else { return false }
        switch status {
        case let .account(accountIndex, hasTradingKey, hasReadOnlyToken, availableBalance, collateral, equity):
            let needsActivation = await Self.needsActivation(
                hasTradingKey: hasTradingKey,
                holdsTradingKey: holdsTradingKey()
            )
            guard !Task.isCancelled else { return false }
            return await applyActive(
                PerpsAccount(
                    accountIndex: accountIndex,
                    availableBalance: availableBalance ?? collateral ?? "0",
                    collateral: collateral,
                    equity: equity ?? collateral,
                    positionsLoaded: hasTradingKey == false,
                    hasTradingKey: hasTradingKey != false,
                    hasReadOnlyToken: hasReadOnlyToken != false,
                    needsActivation: needsActivation
                ),
                issuesReadOnlyToken: !needsActivation && hasReadOnlyToken != true,
                fundingRefreshId: fundingRefreshId
            )
        case .unbound:
            await positionsController?.stop()
            guard !Task.isCancelled else { return false }
            setResolved(state: .unbound)
        case .noAccount, .unknown:
            await positionsController?.stop()
            guard !Task.isCancelled else { return false }
            setResolved(state: .inactive)
        case let .unavailable(reason):
            Log.perps.w("status probe failed — \(reason)")
            return await finishUnresolved()
        }
        return false
    }

    func applyActive(_ venueAccount: PerpsAccount, issuesReadOnlyToken: Bool, fundingRefreshId: UUID?) async -> Bool {
        lock.withLock {
            if self.fundingRefreshId == fundingRefreshId {
                self.fundingRefreshId = nil
            }
        }
        if activeAccount(accountIndex: venueAccount.accountIndex)?.positionsLoaded != true {
            setResolved(state: .active(keepingPositions(venueAccount)))
        }
        if issuesReadOnlyToken {
            _ = await refreshOrderAccess()
            guard !Task.isCancelled else { return false }
        }
        // After the read-only token step: tk-perps reads the tier with that token.
        if !venueAccount.needsActivation {
            Task { [ensureAccountTier] in await ensureAccountTier() }
        }
        reloadRequestedExtras(accountIndex: venueAccount.accountIndex)
        var venueAccount = venueAccount
        var portfolio: PerpsAccountSnapshot?
        if venueAccount.hasTradingKey {
            do {
                portfolio = try await readPortfolio(reissuingUnavailableToken: !venueAccount.needsActivation)
            } catch {
                guard !Task.isCancelled else { return false }
                Log.perps.w("portfolio read failed, showing the account balance — \(error)")
                if (error as? PerpsAPIError)?.isReadOnlyTokenUnavailable == true {
                    venueAccount.hasReadOnlyToken = false
                }
            }
        }
        guard !Task.isCancelled else { return false }
        if let portfolio {
            reconcilePending(positions: portfolio.positions)
            startAutoCloseRenewal(marketIds: portfolio.positions.map(\.marketId))
            setResolved(state: .active(PerpsAccount(
                accountIndex: venueAccount.accountIndex,
                availableBalance: portfolio.availableBalance,
                collateral: portfolio.collateral,
                equity: portfolio.equity,
                transferableBalance: portfolio.transferableBalance,
                positions: portfolio.positions,
                openOrders: portfolio.openOrders,
                hasTradingKey: venueAccount.hasTradingKey,
                hasReadOnlyToken: venueAccount.hasReadOnlyToken,
                needsActivation: venueAccount.needsActivation
            )))
        } else {
            setResolved(state: .active(keepingPositions(venueAccount)))
        }
        startOperationRecovery()
        positionsController?.start()
        return false
    }

    func readPortfolio(reissuingUnavailableToken: Bool) async throws -> PerpsAccountSnapshot? {
        do {
            return try await service.portfolio(wallet: wallet)
        } catch let error as PerpsAPIError where reissuingUnavailableToken && error.isReadOnlyTokenUnavailable {
            guard !Task.isCancelled, await reissueReadOnlyToken() else { throw error }
            return try await service.portfolio(wallet: wallet)
        }
    }

    func activeAccount(accountIndex: Int64) -> PerpsAccount? {
        guard case let .active(account) = currentWalletState(), account.accountIndex == accountIndex else { return nil }
        return account
    }

    func keepingPositions(_ venueAccount: PerpsAccount) -> PerpsAccount {
        guard let current = activeAccount(accountIndex: venueAccount.accountIndex) else { return venueAccount }
        var account = venueAccount
        account.positions = current.positions
        account.openOrders = current.openOrders
        account.positionsLoaded = current.positionsLoaded
        return account
    }

    func setResolved(state: State) {
        lock.withLock { resolveFailures = 0 }
        setState(state, markResolved: true)
        if case .active = state {} else {
            stopOperationRecovery()
        }
    }

    func finishUnresolved() async -> Bool {
        // The task handle is kept for the same reason `setState` keeps it: dropping it here
        // would leave the stop round-trip below running with nothing able to cancel it once a
        // newer resolve supersedes this one, and `isResolved` is re-read afterwards because a
        // resolve that settled the account in the meantime must not be published over.
        let shouldPublish = lock.withLock {
            isResolving = false
            return !isResolved
        }
        guard shouldPublish else { return false }
        await positionsController?.stop()
        guard !Task.isCancelled, lock.withLock({ !isResolved }) else { return false }
        setState(.unresolved)
        stopOperationRecovery()
        return true
    }

    func waitToRetry() async -> Bool {
        let delay: TimeInterval? = lock.withLock {
            guard resolveFailures < resolveRetryDelays.count else { return nil }
            defer { resolveFailures += 1 }
            return resolveRetryDelays[resolveFailures]
        }
        guard let delay else { return false }
        await waitBeforeRetry(delay)
        // Under the lock a newer resolve cancels this task in, so waking up either sees the
        // cancellation or marks the retry before that resolve can take over.
        return lock.withLock {
            guard !Task.isCancelled, !isResolved else { return false }
            isResolving = true
            return true
        }
    }

    func reconcilePending(positions: [PerpsPositionSummary]) {
        let positionsByMarket = Dictionary(positions.map { ($0.marketId, $0) }, uniquingKeysWith: { first, _ in first })
        let settled: [Int64: Pending.Kind] = lock.withLock {
            let before = pendingByMarket
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
            return before.filter { pendingByMarket[$0.key] == nil }.mapValues(\.kind)
        }
        if !settled.isEmpty {
            Log.perps.i("overlay settled by portfolio \(settled)")
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

    func fetchMarketExtras(accountIndex: Int64, marketId: Int64, retryAfterOrderAccess: Bool = true, clearingPending: Bool = false) {
        let requestId = UUID()
        lock.withLock {
            marketExtrasRequestIds[marketId] = requestId
            if clearingPending {
                pendingByMarket[marketId]?.clearsAfterExtrasReload = true
            }
        }
        Task { [weak self] in
            guard let self else { return }
            async let trading = self.tradingSnapshotResult(accountIndex: accountIndex, marketId: marketId)
            async let activity = self.recentHistoryResult(marketId: marketId)
            let (tradingResult, activityResult) = await(trading, activity)
            if case let .failure(error) = tradingResult {
                Log.perps.w("trading-screen fetch failed market=\(marketId) — \(error)")
            }
            if case let .failure(error) = activityResult {
                Log.perps.w("recent-history fetch failed market=\(marketId) — \(error)")
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
            if case .success = tradingResult,
               activeOrders == nil,
               retryAfterOrderAccess,
               await self.refreshOrderAccess()
            {
                self.fetchMarketExtras(
                    accountIndex: accountIndex,
                    marketId: marketId,
                    retryAfterOrderAccess: false
                )
                return
            }
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
                if self.pendingByMarket[marketId]?.clearsAfterExtrasReload == true {
                    self.pendingByMarket[marketId] = nil
                }
                return true
            }
            if stored { self.notifyLifecycleChanged() }
        }
    }

    func applyOrderProgress(_ progress: [PerpsOrderProgress]) {
        guard case let .active(account) = currentWalletState() else { return }
        let answers = Dictionary(progress.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let markets = lock.withLock { () -> Set<Int64> in
            var moved = Set<Int64>()
            for (marketId, entry) in marketExtrasByMarket
                where requestedExtrasMarkets.contains(marketId) && entry.accountIndex == account.accountIndex
            {
                for order in entry.extras.limitOrders {
                    guard let answer = answers[order.id] else { continue }
                    if !answer.isResting || answer.filledBaseAmount != order.filledBaseAmount {
                        moved.insert(marketId)
                    }
                }
            }
            return moved
        }
        guard !markets.isEmpty else { return }
        for marketId in markets {
            loadMarketExtras(marketId: marketId)
        }
        refresh()
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
            let positionId = matchingPosition(marketId: marketId)?.positionId
            return try .success(await PerpsAPIError.reissuingReadOnlyToken(reissueReadOnlyToken) {
                try await service.tradingSnapshot(wallet: wallet, marketId: marketId, positionId: positionId)
            })
        } catch {
            return .failure(error)
        }
    }

    func recentHistoryResult(marketId: Int64) async -> Result<[PerpsHistoryEvent], Error> {
        do {
            return try .success(await loadHistory(marketId, Self.recentHistoryLimit))
        } catch {
            return .failure(error)
        }
    }

    static let recentHistoryLimit = 5

    func finishMarketExtrasFetch(marketId: Int64, requestId: UUID) {
        let cleared = lock.withLock { () -> Bool in
            guard marketExtrasRequestIds[marketId] == requestId else { return false }
            marketExtrasRequestIds[marketId] = nil
            if pendingByMarket[marketId]?.clearsAfterExtrasReload == true {
                pendingByMarket[marketId] = nil
                return true
            }
            return false
        }
        if cleared { notifyLifecycleChanged() }
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
        let recoveryTasks = operationRecoveryLock.withLock { () -> [Task<Void, Never>?] in
            let tasks = [operationRecoveryTask, operationRecoveryRetryTask, autoCloseRenewal?.task]
            operationRecoveryGeneration = nil
            operationRecoveryTask = nil
            operationRecoveryRetryTask = nil
            operationRecoveryRequested = false
            autoCloseRenewal = nil
            return tasks
        }
        recoveryTasks.forEach { $0?.cancel() }
    }

    func startAutoCloseRenewal(marketIds: [Int64]) {
        let id = UUID()
        operationRecoveryLock.withLock {
            guard autoCloseRenewal == nil else { return }
            let task = Task { [weak self, renewAutoClose] in
                await renewAutoClose(marketIds)
                self?.finishAutoCloseRenewal(id: id)
            }
            autoCloseRenewal = (id, task)
        }
    }

    func finishAutoCloseRenewal(id: UUID) {
        operationRecoveryLock.withLock {
            if autoCloseRenewal?.id == id { autoCloseRenewal = nil }
        }
    }

    internal func watchFocus() -> PerpsWatchFocus {
        guard case let .active(account) = currentWalletState() else { return .positions }
        let restingOrders: [PerpsLimitOrderSummary]? = lock.withLock {
            guard pendingByMarket.isEmpty else { return nil }
            return marketExtrasByMarket
                .filter { requestedExtrasMarkets.contains($0.key) && $0.value.accountIndex == account.accountIndex }
                .values
                .flatMap { $0.extras.limitOrders }
        }
        guard let restingOrders else { return .positions }
        return Self.watchFocus(
            hasPositions: !account.positions.isEmpty || !account.positionsLoaded || !account.openOrders.isEmpty,
            restingOrders: restingOrders
        )
    }

    internal static func watchFocus(restingOrders: [PerpsLimitOrderSummary]) -> PerpsWatchFocus {
        guard !restingOrders.isEmpty else { return .idle }
        let ids = restingOrders.map(\.id)
        guard ids.allSatisfy({ !$0.isEmpty }) else { return .positions }
        return .orders(ids)
    }

    internal static func watchFocus(hasPositions: Bool, restingOrders: [PerpsLimitOrderSummary]) -> PerpsWatchFocus {
        switch (hasPositions, watchFocus(restingOrders: restingOrders)) {
        case (false, let .orders(ids)): return .orders(ids)
        case (false, _): return .idle
        case (true, let .orders(ids)): return .positionsAndOrders(ids)
        case (true, _): return .positions
        }
    }

    func applyPositionsTick(_ tick: PerpsAccountTick) {
        guard case let .active(account) = currentWalletState() else { return }
        switch tick {
        case let .orders(progress):
            applyOrderProgress(progress)
        case let .positions(positions, openOrders):
            applyPositionUpdate(positions, openOrders: openOrders, account: account)
        case let .positionsAndOrders(positions, progress, openOrders):
            applyPositionUpdate(positions, openOrders: openOrders, account: account)
            applyOrderProgress(progress)
        }
    }

    func applyPositionUpdate(
        _ positions: [PerpsPositionSummary],
        openOrders: [PerpsPortfolioOrder]?,
        account: State.Account
    ) {
        // A socket snapshot must not blank an existing position on its own: an empty list
        // during a reconnect blip would flash `.flat` (Long/Short) on a market the user
        // still holds. Defer to an authoritative REST read, which also reflects a genuine
        // full close a beat later.
        if positions.isEmpty, !account.positions.isEmpty {
            refresh()
            return
        }
        reconcilePending(positions: positions)
        var updated = account
        updated.positions = positions
        updated.openOrders = openOrders ?? account.openOrders
        updated.positionsLoaded = true
        setResolved(state: .active(updated))
        refreshExtrasForPositionFlips(accountIndex: account.accountIndex, positions: positions)
        if let openOrders, !Self.sameOrders(openOrders, account.openOrders) { refresh() }
    }

    internal static func sameOrders(_ lhs: [PerpsPortfolioOrder], _ rhs: [PerpsPortfolioOrder]) -> Bool {
        func key(_ order: PerpsPortfolioOrder) -> (Int64, Int64) {
            (order.marketId, order.order.orderIndex)
        }
        return lhs.sorted { key($0) < key($1) } == rhs.sorted { key($0) < key($1) }
    }

    private func refreshExtrasForPositionFlips(accountIndex: Int64, positions: [PerpsPositionSummary]) {
        let shapes = Self.positionShapes(positions)
        let toRefresh: [Int64] = lock.withLock {
            defer { lastPositionShapes = shapes }
            guard didSeedPositionedMarkets else {
                didSeedPositionedMarkets = true
                return []
            }
            let moved = Self.marketsWithMovedPositions(before: lastPositionShapes, after: shapes)
            return requestedExtrasMarkets.intersection(moved).sorted()
        }
        for marketId in toRefresh {
            fetchMarketExtras(accountIndex: accountIndex, marketId: marketId)
        }
    }

    internal static func positionShapes(_ positions: [PerpsPositionSummary]) -> [Int64: PositionShape] {
        positions.reduce(into: [Int64: PositionShape]()) { shapes, position in
            shapes[position.marketId] = PositionShape(side: position.side, baseSize: position.baseSize)
        }
    }

    internal static func marketsWithMovedPositions(
        before: [Int64: PositionShape],
        after: [Int64: PositionShape]
    ) -> Set<Int64> {
        var moved = Set(before.keys).symmetricDifference(after.keys)
        for (marketId, shape) in after {
            guard let previous = before[marketId] else { continue }
            if previous.side != shape.side || !Self.sameSize(previous.baseSize, shape.baseSize) {
                moved.insert(marketId)
            }
        }
        return moved
    }

    static func sameSize(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(lhs - rhs) <= max(1e-9, max(abs(lhs), abs(rhs)) * 1e-9)
    }

    func setState(_ newState: State, markResolved: Bool = false) {
        setStateNotifying(newState, event: Event.didUpdate) { [weak self] _ in
            guard let self, markResolved else { return }
            // The task is kept: publishing a state happens mid-resolve, and dropping the handle
            // here would leave the rest of that resolve — the extras reload, the recovery and the
            // positions watch — running with nothing able to cancel it when a newer resolve
            // supersedes it. `resolveIfNeeded` settles on the flags, not on this handle.
            self.lock.withLock {
                self.isResolved = true
                self.isResolving = false
            }
        }
    }
}

extension PerpsAccountStore {
    func flushPositionsForTesting() async {
        await positionsController?.flush()
    }

    var resolveTaskForTesting: Task<Void, Never>? {
        lock.withLock { resolveTask }
    }

    /// `Store` publishes through its own serial queue, so a state set by a finished resolve is
    /// readable only after everything queued before this hop has run.
    func flushStateForTesting() async {
        await withCheckedContinuation { continuation in
            updateState({ _ in nil }) { _ in continuation.resume() }
        }
    }
}

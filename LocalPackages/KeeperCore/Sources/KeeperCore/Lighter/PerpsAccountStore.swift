import ChainKit
import Foundation
import PerpsModels
import TKLogging

enum PerpsTradeInProgress: Equatable {
    case opening(PerpsOpeningDescriptor)
    case closing
    /// `baseSizeBefore` must be the prepare-time venue read (the baseline the
    /// size-change reconciliation confirms against) — the live stream may already
    /// differ by the time the user swipes.
    case adjusting(PerpsSizeChangeDirection, baseSizeBefore: Double)
    /// `allocatedMarginBefore` must be the prepare-time venue read (the baseline the
    /// margin-change reconciliation confirms against) — the live stream may already
    /// differ by the time the user swipes.
    case adjustingMargin(PerpsMarginChangeDirection, allocatedMarginBefore: Double, amountUsd: Double)
}

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

        let operationId: String
        let kind: Kind
        var succeeded = false
        var clearsAfterExtrasReload = false

        var isPlacedLimitOrder: Bool {
            guard succeeded, case let .opening(descriptor) = kind else { return false }
            return descriptor.isLimit
        }
    }

    private var pendingByMarket: [Int64: Pending] = [:]
    /// What a market open filled, shown until the portfolio has the position.
    private var countedByMarket: [Int64: (position: PerpsPositionSummary, at: Date)] = [:]

    private var requestedExtrasMarkets: Set<Int64> = []
    private var marketExtrasByMarket: [Int64: (accountIndex: Int64, extras: PerpsMarketExtras)] = [:]
    private var marketExtrasRequestIds: [Int64: UUID] = [:]
    struct PositionShape: Equatable {
        let side: PerpsTradeSide
        let baseSize: Double
    }

    private var positionsController: PerpsPositionsController?

    private let service: PerpsAccountReading
    private let wallet: Wallet
    private let recoverOperations: @Sendable () -> Void
    private let renewAutoClose: @Sendable (_ marketIds: [Int64]) -> Void
    private let reissueReadOnlyToken: @Sendable () async -> Bool
    private let holdsTradingKey: @Sendable () async -> Bool
    private let ensureAccountTier: @Sendable () async -> Void
    private let loadHistory: @Sendable (_ marketId: Int64, _ limit: Int) async throws -> [PerpsHistoryEvent]
    private let persistDepositAcknowledgements: @Sendable (Set<String>) async throws -> Void
    private let positionsCountDefaults: UserDefaults
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
    private var acknowledgedDepositIds: Set<String> = []
    private var fundingRefreshId: UUID?
    private var shownReadRequestedAt: TimeInterval?
    private var closeWrites: [String: Task<Void, Never>] = [:]

    init(
        service: PerpsAccountReading,
        wallet: Wallet,
        recoverOperations: @escaping @Sendable () -> Void = {},
        renewAutoClose: @escaping @Sendable (_ marketIds: [Int64]) -> Void = { _ in },
        reissueReadOnlyToken: @escaping @Sendable () async -> Bool = { false },
        holdsTradingKey: @escaping @Sendable () async -> Bool = { true },
        ensureAccountTier: @escaping @Sendable () async -> Void = {},
        loadHistory: @escaping @Sendable (_ marketId: Int64, _ limit: Int) async throws -> [PerpsHistoryEvent] = { _, _ in [] },
        observeHistoryChanges: (_ observer: AnyObject, _ onChange: @escaping () -> Void) -> Void = { _, _ in },
        persistDepositAcknowledgements: @escaping @Sendable (Set<String>) async throws -> Void = { _ in },
        positionsCountDefaults: UserDefaults = .standard,
        resolveRetryDelays: [TimeInterval] = [2, 5, 10, 20, 30],
        waitBeforeRetry: @escaping @Sendable (TimeInterval) async -> Void = {
            try? await Task.sleep(nanoseconds: UInt64($0 * 1_000_000_000))
        }
    ) {
        self.service = service
        self.wallet = wallet
        self.recoverOperations = recoverOperations
        self.renewAutoClose = renewAutoClose
        self.reissueReadOnlyToken = reissueReadOnlyToken
        self.holdsTradingKey = holdsTradingKey
        self.ensureAccountTier = ensureAccountTier
        self.loadHistory = loadHistory
        self.persistDepositAcknowledgements = persistDepositAcknowledgements
        self.positionsCountDefaults = positionsCountDefaults
        self.resolveRetryDelays = resolveRetryDelays
        self.waitBeforeRetry = waitBeforeRetry
        super.init(state: .unresolved)
        positionsController = PerpsPositionsController(
            makeWatch: { [weak self] cadence, onUpdate, onInterrupted in
                guard let self else { return PerpsPositionsWatch {} }
                return self.service.watchPositions(
                    wallet: self.wallet,
                    pollInterval: cadence.pollInterval,
                    focus: { [weak self] in self?.watchFocus() ?? .portfolio },
                    onUpdate: onUpdate,
                    onInterrupted: onInterrupted
                )
            },
            onUpdate: { [weak self] in self?.applyPositionsTick($0) },
            onInterrupted: { [weak self] in self?.refresh() }
        )
        observeHistoryChanges(self) { [weak self] in self?.reloadMarketExtras() }
    }

    deinit {
        lock.withLock { resolveTask }?.cancel()
    }

    override public func createInitialState() -> State {
        .unresolved
    }

    public var rememberedPositionsCount: Int? {
        positionsCountDefaults.object(forKey: positionsCountKey) as? Int
    }

    public func rememberPositionsCount(_ count: Int) {
        guard rememberedPositionsCount != count else { return }
        positionsCountDefaults.set(count, forKey: positionsCountKey)
    }

    private var positionsCountKey: String {
        "perps.positionsCount.\(wallet.id).\(PerpsEnvironment.storage)"
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

    /// Follows the user's action — a trade, a withdraw, an activation — or a pull to refresh,
    /// so no read that started before it may answer it.
    public func refresh() {
        service.invalidateSharedReads()
        refreshOnAppear()
    }

    /// Unlike `refresh()`, a portfolio read made a moment ago or still in flight answers it:
    /// a screen opening starts a positions poll and this resolve together.
    public func refreshOnAppear() {
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
        var failed: Set<String> = []
        var transactions: [String: Set<String>] = [:]
        var withdrawals: Set<String> = []
        var deposits: [PerpsDepositStatus] = []
        let (funding, isBalanceRefreshing, acknowledged) = lock.withLock { (fundingState, fundingRefreshId != nil, acknowledgedDepositIds) }
        for operation in funding.operations {
            let hashes = operation.transactionHashes
            if !hashes.isEmpty { transactions[operation.operationId] = hashes }
            if let deposit = operation.deposit {
                if let status = operation.depositStatus { deposits.append(status) }
                let stage = deposit.stage
                if stage.isInFlight { inFlight.insert(operation.operationId) }
                if stage == .credited { completed.insert(operation.operationId) }
                if stage == .failed || stage == .refunded { failed.insert(operation.operationId) }
            } else if let stage = operation.withdraw?.stage {
                withdrawals.insert(operation.operationId)
                let refusedNonce = operation.withdraw?.isRefusedForNonce == true
                if stage == .signed || stage == .sending || (stage == .unknown && !refusedNonce) { inFlight.insert(operation.operationId) }
                if stage == .accepted || stage == .awaitingL1 { pending.insert(operation.operationId) }
                if stage == .settled { completed.insert(operation.operationId) }
                if stage == .rejected { failed.insert(operation.operationId) }
            }
        }
        return PerpsFundingActivity(isBalanceRefreshing: isBalanceRefreshing, deposits: deposits.sorted { ($0.createdAt, $0.id) > ($1.createdAt, $1.id) }, inFlight: inFlight, pending: pending, completed: completed, failed: failed, transactions: transactions, withdrawals: withdrawals, acknowledgedDepositIds: acknowledged)
    }

    public func acknowledgeDepositStatuses(_ operationIds: Set<String>) {
        let acknowledged = lock.withLock {
            let settled = fundingState.operations.compactMap { operation -> String? in
                guard let deposit = operation.deposit,
                      deposit.stage.isOutcome || deposit.stage.isStalled
                else { return nil }
                return operation.operationId
            }
            let ids = operationIds.intersection(settled).subtracting(acknowledgedDepositIds)
            acknowledgedDepositIds.formUnion(ids)
            return ids
        }
        guard !acknowledged.isEmpty else { return }
        sendEvent(.didUpdateFunding(currentFundingState()))
        Task { [persistDepositAcknowledgements, walletId = wallet.id] in
            do {
                try await persistDepositAcknowledgements(acknowledged)
            } catch {
                PerpsOperationLog.event("deposit_status_acknowledgement", outcome: "failed", source: "journal", error: error, fields: ["wallet_id": walletId])
            }
        }
    }

    func applyFundingState(_ state: PerpsFundingState) {
        let (changed, needsRefresh) = lock.withLock {
            let previous = fundingState
            guard previous != state else { return (false, false) }
            fundingState = state
            acknowledgedDepositIds.formUnion(state.operations.compactMap {
                $0.deposit?.statusAcknowledged == true ? $0.operationId : nil
            })
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
        let (pending, counted) = lock.withLock { (pendingByMarket[marketId], countedByMarket[marketId]?.position) }
        let position = matchingPosition(marketId: marketId) ?? counted
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

    func matchingPosition(marketId: Int64) -> PerpsPositionSummary? {
        guard case let .active(account) = currentWalletState() else { return nil }
        return account.positions.first { $0.marketId == marketId }
    }

    func tradeBegan(operationId: String, marketId: Int64, _ trade: PerpsTradeInProgress) {
        let counted = lock.withLock { countedByMarket[marketId]?.position }
        let kind: Pending.Kind
        switch trade {
        case let .opening(descriptor):
            kind = .opening(descriptor)
        case .closing:
            guard let position = matchingPosition(marketId: marketId) ?? counted else { return }
            kind = .closing(position.side, baseSizeBefore: position.baseSize)
        case let .adjusting(direction, baseSizeBefore):
            kind = .adjusting(direction, baseSizeBefore: baseSizeBefore)
        case let .adjustingMargin(direction, allocatedMarginBefore, amountUsd):
            kind = .adjustingMargin(direction, allocatedMarginBefore: allocatedMarginBefore, amountUsd: amountUsd)
        }
        Log.perps.i("overlay \(kind) market=\(marketId) operation=\(operationId)")
        lock.withLock { pendingByMarket[marketId] = Pending(operationId: operationId, kind: kind) }
        notifyLifecycleChanged()
    }

    func tradeSettled(operationId: String, succeeded: Bool) {
        let (cleared, closedCount) = lock.withLock { () -> (Pending?, PerpsPositionSummary?) in
            guard let marketId = pendingByMarket.first(where: { $0.value.operationId == operationId })?.key else { return (nil, nil) }
            guard succeeded else { return (pendingByMarket.removeValue(forKey: marketId), nil) }
            pendingByMarket[marketId]?.succeeded = true
            guard case .closing = pendingByMarket[marketId]?.kind else { return (nil, nil) }
            return (nil, countedByMarket.removeValue(forKey: marketId)?.position)
        }
        if let cleared {
            Log.perps.i("overlay cleared operation=\(operationId) was=\(cleared.kind)")
        }
        if let closedCount {
            Log.perps.i("overlay count closed market=\(closedCount.marketId) operation=\(operationId)")
        }
        if cleared != nil || closedCount != nil {
            notifyLifecycleChanged()
        }
    }

    func positionCounted(operationId: String, _ counted: PerpsCountedPosition) {
        let summary = lock.withLock { () -> PerpsPositionSummary? in
            guard let marketId = pendingByMarket.first(where: { $0.value.operationId == operationId })?.key,
                  let pending = pendingByMarket[marketId], pending.succeeded,
                  case let .opening(descriptor) = pending.kind, !descriptor.isLimit,
                  let liquidationPrice = descriptor.liquidationPrice, liquidationPrice > 0
            else { return nil }
            let summary = counted.summary(descriptor, liquidationPrice: liquidationPrice)
            countedByMarket[marketId] = (summary, Date())
            return summary
        }
        guard let summary else { return }
        Log.perps.i("overlay counted market=\(summary.marketId) size=\(summary.baseSize) operation=\(operationId)")
        notifyLifecycleChanged()
    }

    func positionClosed(operationId: String, marketId: Int64) async {
        await closeWrite(operationId: operationId, marketId: marketId).value
    }

    private func closeWrite(operationId: String, marketId: Int64) -> Task<Void, Never> {
        lock.lock()
        defer { lock.unlock() }
        if let write = closeWrites[operationId] {
            return write
        }
        let confirmedAt = ProcessInfo.processInfo.systemUptime
        shownReadRequestedAt = max(shownReadRequestedAt ?? confirmedAt, confirmedAt)
        let write = Task { [weak self] in
            guard let self else { return }
            await takeOutClosedPosition(operationId: operationId, marketId: marketId)
        }
        closeWrites[operationId] = write
        return write
    }

    private func takeOutClosedPosition(operationId: String, marketId: Int64) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            updateState { state in
                guard case var .active(account) = state, account.positions.contains(where: { $0.marketId == marketId }) else { return nil }
                account.positions.removeAll { $0.marketId == marketId }
                return StateUpdate(newState: .active(account))
            } completion: { [weak self] state in
                if let self {
                    lock.withLock {
                        if self.pendingByMarket[marketId]?.operationId == operationId {
                            self.pendingByMarket[marketId] = nil
                        }
                    }
                    sendEvent(.didUpdate(state))
                }
                continuation.resume()
            }
        }
        Log.perps.i("close confirmed market=\(marketId) operation=\(operationId)")
        refresh()
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
        guard case let .active(account) = currentWalletState() else {
            let cleared = lock.withLock {
                guard pendingByMarket[marketId]?.isPlacedLimitOrder == true else { return false }
                pendingByMarket[marketId] = nil
                return true
            }
            if cleared { notifyLifecycleChanged() }
            return
        }
        fetchMarketExtras(accountIndex: account.accountIndex, marketId: marketId, reason: "load")
    }

    public func releaseMarketExtras(marketId: Int64) {
        lock.withLock {
            requestedExtrasMarkets.remove(marketId)
            if pendingByMarket[marketId]?.clearsAfterExtrasReload != true {
                marketExtrasRequestIds[marketId] = nil
            }
        }
    }

    private func reloadMarketExtras() {
        guard case let .active(account) = currentWalletState() else { return }
        reloadRequestedExtras(accountIndex: account.accountIndex)
    }

    // MARK: - Live positions stream

    public func subscribePositions(cadence: PerpsPositionsCadence = .live) {
        positionsController?.subscribe(cadence: cadence)
    }

    public func unsubscribePositions(cadence: PerpsPositionsCadence = .live) {
        positionsController?.unsubscribe(cadence: cadence)
    }

    public func setForeground(_ isForeground: Bool) {
        positionsController?.setForeground(isForeground)
    }
}

private extension PerpsAccountStore {
    struct PortfolioPrefetch {
        let accountIndex: Int64
        let task: Task<PerpsAccountSnapshot?, Error>
    }

    func resolve(showResolving: Bool) {
        if showResolving {
            // Published before the stop round-trip rather than after it: a resolve cancelled while
            // waiting would otherwise leave the store unresolved with the previous state on screen.
            // Applying a tick already requires `.active`, so a late one is a no-op either way.
            setState(.resolving)
        }
        lock.withLock {
            resolveTask?.cancel()
            isResolving = true
            if showResolving { isResolved = false }
            resolveTask = Task { [weak self, waitBeforeRetry] in
                if showResolving {
                    await self?.positionsController?.stop()
                    guard !Task.isCancelled else { return }
                }
                // Retries stay inside this task, so a newer resolve cancels them together with it
                // and a retry never replaces anything.
                while await self?.attemptResolve() == true, let delay = self?.nextRetryDelay() {
                    await waitBeforeRetry(delay)
                    guard self?.beginRetry() == true else { return }
                }
            }
        }
    }

    /// Returns whether the attempt left the account unresolved, i.e. whether it is worth retrying.
    func attemptResolve() async -> Bool {
        let fundingRefreshId = lock.withLock { self.fundingRefreshId }
        let prefetch = portfolioPrefetch()
        defer { prefetch?.task.cancel() }
        if let prefetch {
            reloadRequestedExtras(accountIndex: prefetch.accountIndex)
        }
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
                fundingRefreshId: fundingRefreshId,
                prefetch: prefetch
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

    /// An account already active with both keys in place needs no answer from the status probe
    /// to read its portfolio, so the two reads go out together instead of one after the other.
    func portfolioPrefetch() -> PortfolioPrefetch? {
        guard case let .active(account) = currentWalletState(),
              account.hasTradingKey, account.hasReadOnlyToken, !account.needsActivation
        else { return nil }
        let accountIndex = account.accountIndex
        let task = Task { [weak self] () async throws -> PerpsAccountSnapshot? in
            let snapshot = try await self?.readPortfolio(reissuingUnavailableToken: true)
            if let snapshot, !Task.isCancelled {
                self?.applyPrefetchedPortfolio(snapshot, accountIndex: accountIndex)
            }
            return snapshot
        }
        return PortfolioPrefetch(accountIndex: accountIndex, task: task)
    }

    /// Shows the prefetched portfolio without waiting for the status probe, so the overlay of
    /// a trade that just settled goes away with it. Unlike a positions tick it never refreshes
    /// on a new market: the resolve that started this read is still running and applies it again.
    func applyPrefetchedPortfolio(_ snapshot: PerpsAccountSnapshot, accountIndex: Int64) {
        applyRead(requestedAt: snapshot.requestedAt, showing: { current in
            guard let current, current.accountIndex == accountIndex else { return nil }
            return Self.account(current, holding: snapshot)
        })
    }

    func applyActive(
        _ venueAccount: PerpsAccount,
        issuesReadOnlyToken: Bool,
        fundingRefreshId: UUID?,
        prefetch: PortfolioPrefetch? = nil
    ) async -> Bool {
        if activeAccount(accountIndex: venueAccount.accountIndex)?.positionsLoaded != true {
            setResolved(state: .active(keepingPositions(venueAccount)))
        }
        if issuesReadOnlyToken {
            _ = await reissueReadOnlyToken()
            guard !Task.isCancelled else { return false }
        }
        // After the read-only token step: tk-perps reads the tier with that token.
        if !venueAccount.needsActivation {
            Task { [ensureAccountTier] in await ensureAccountTier() }
        }
        var venueAccount = venueAccount
        var portfolio: PerpsAccountSnapshot?
        // The prefetch stands only for the account it was started for, read with the token it
        // already had; anything that changed under it reads again after the status.
        let usable = prefetch.flatMap {
            $0.accountIndex == venueAccount.accountIndex && !issuesReadOnlyToken && !venueAccount.needsActivation ? $0 : nil
        }
        if usable == nil {
            prefetch?.task.cancel()
            reloadRequestedExtras(accountIndex: venueAccount.accountIndex)
        }
        if venueAccount.hasTradingKey {
            do {
                if let usable {
                    portfolio = try await withTaskCancellationHandler {
                        try await usable.task.value
                    } onCancel: {
                        usable.task.cancel()
                    }
                } else {
                    portfolio = try await readPortfolio(reissuingUnavailableToken: !venueAccount.needsActivation)
                }
            } catch {
                guard !Task.isCancelled else { return false }
                Log.perps.w("portfolio read failed, showing the account balance — \(error)")
                if (error as? PerpsAPIError)?.isReadOnlyTokenUnavailable == true {
                    venueAccount.hasReadOnlyToken = false
                }
            }
        }
        guard !Task.isCancelled else { return false }
        lock.withLock {
            if self.fundingRefreshId == fundingRefreshId {
                self.fundingRefreshId = nil
            }
        }
        if let portfolio {
            let venueAccount = venueAccount
            applyRead(
                requestedAt: portfolio.requestedAt,
                showing: { _ in Self.account(venueAccount, holding: portfolio) },
                keeping: { current in current.map { Self.account(venueAccount, keeping: $0) } ?? venueAccount },
                shown: { [renewAutoClose] _, shown in renewAutoClose(shown.positions.map(\.marketId)) }
            )
        } else {
            setResolved(state: .active(keepingPositions(venueAccount)))
        }
        recoverOperations()
        positionsController?.start()
        return false
    }

    func applyRead(
        requestedAt: TimeInterval?,
        showing: @escaping (_ current: PerpsAccount?) -> PerpsAccount?,
        keeping: @escaping (_ current: PerpsAccount?) -> PerpsAccount? = { _ in nil },
        shown: @escaping (_ before: PerpsAccount?, _ after: PerpsAccount) -> Void = { _, _ in }
    ) {
        var change: (before: PerpsAccount?, after: PerpsAccount)?
        updateState { [weak self] state in
            guard let self else { return nil }
            let current: PerpsAccount? = if case let .active(account) = state { account } else { nil }
            guard let read = showing(current) else { return nil }
            let after: PerpsAccount
            if isNewestRead(requestedAt) {
                reconcilePending(positions: read.positions)
                after = read
            } else {
                Log.perps.i("portfolio read requested before the shown one, not shown")
                guard let kept = keeping(current) else { return nil }
                after = kept
            }
            change = (current, after)
            return StateUpdate(newState: .active(after))
        } completion: { [weak self] state in
            guard let self, let change else { return }
            lock.withLock {
                self.resolveFailures = 0
                self.isResolved = true
                self.isResolving = false
            }
            sendEvent(.didUpdate(state))
            shown(change.before, change.after)
        }
    }

    func isNewestRead(_ requestedAt: TimeInterval?) -> Bool {
        guard let requestedAt else { return true }
        return lock.withLock {
            if let shown = shownReadRequestedAt, requestedAt < shown { return false }
            shownReadRequestedAt = requestedAt
            return true
        }
    }

    static func account(_ flags: PerpsAccount, holding snapshot: PerpsAccountSnapshot) -> PerpsAccount {
        PerpsAccount(
            accountIndex: flags.accountIndex,
            availableBalance: snapshot.availableBalance,
            collateral: snapshot.collateral,
            equity: snapshot.equity,
            transferableBalance: snapshot.transferableBalance,
            positions: snapshot.positions,
            openOrders: snapshot.openOrders,
            hasTradingKey: flags.hasTradingKey,
            hasReadOnlyToken: flags.hasReadOnlyToken,
            needsActivation: flags.needsActivation
        )
    }

    static func account(_ flags: PerpsAccount, keeping current: PerpsAccount) -> PerpsAccount {
        guard current.accountIndex == flags.accountIndex else { return flags }
        return PerpsAccount(
            accountIndex: flags.accountIndex,
            availableBalance: current.availableBalance,
            collateral: current.collateral,
            equity: current.equity,
            transferableBalance: current.transferableBalance,
            positions: current.positions,
            openOrders: current.openOrders,
            positionsLoaded: current.positionsLoaded,
            hasTradingKey: flags.hasTradingKey,
            hasReadOnlyToken: flags.hasReadOnlyToken,
            needsActivation: flags.needsActivation
        )
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
        return true
    }

    func nextRetryDelay() -> TimeInterval? {
        lock.withLock {
            guard resolveFailures < resolveRetryDelays.count else { return nil }
            defer { resolveFailures += 1 }
            return resolveRetryDelays[resolveFailures]
        }
    }

    func beginRetry() -> Bool {
        // Under the lock a newer resolve cancels this task in, so waking up either sees the
        // cancellation or marks the retry before that resolve can take over.
        lock.withLock {
            guard !Task.isCancelled, !isResolved else { return false }
            isResolving = true
            return true
        }
    }

    func reconcilePending(positions: [PerpsPositionSummary]) {
        let positionsByMarket = Dictionary(positions.map { ($0.marketId, $0) }, uniquingKeysWith: { first, _ in first })
        var shownCounts: [(counted: PerpsPositionSummary, at: Date, portfolio: PerpsPositionSummary)] = []
        let settled: [Int64: Pending.Kind] = lock.withLock {
            let before = pendingByMarket
            shownCounts = countedByMarket.compactMap { marketId, counted in
                guard case .opening = before[marketId]?.kind, let portfolio = positionsByMarket[marketId] else { return nil }
                return (counted.position, counted.at, portfolio)
            }
            countedByMarket = countedByMarket.filter { positionsByMarket[$0.key] == nil }
            pendingByMarket = pendingByMarket.filter { marketId, pending in
                let position = positionsByMarket[marketId] ?? countedByMarket[marketId]?.position
                switch pending.kind {
                case .opening: return positionsByMarket[marketId] == nil
                case let .closing(side, baseSizeBefore):
                    guard let position else { return false }
                    return position.side == side && !PerpsChangeSettlement.closeMoved(
                        current: position.baseSize,
                        before: baseSizeBefore
                    )
                case let .adjusting(direction, baseSizeBefore):
                    guard let position else { return false }
                    return !PerpsChangeSettlement.sizeMoved(
                        current: position.baseSize,
                        before: baseSizeBefore,
                        direction: direction
                    )
                case let .adjustingMargin(direction, allocatedMarginBefore, amountUsd):
                    guard let position else { return false }
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
        for shown in shownCounts {
            Self.logCountedAgainstPortfolio(shown.counted, shown.portfolio, countedAt: shown.at)
        }
    }

    /// How far the count shown after an open was from the portfolio that replaced it.
    static func logCountedAgainstPortfolio(_ counted: PerpsPositionSummary, _ portfolio: PerpsPositionSummary, countedAt: Date?) {
        func offPercent(_ shown: Double, _ venue: Double) -> Double {
            venue == 0 ? (shown == 0 ? 0 : 100) : abs(shown - venue) / abs(venue) * 100
        }
        let entryOff = offPercent(counted.entryPrice, portfolio.entryPrice)
        let marginOff = offPercent(counted.marginUsd, portfolio.marginUsd)
        let liquidationOff = offPercent(counted.liquidationPrice, portfolio.liquidationPrice)
        let sizeMatches = abs(counted.baseSize - portfolio.baseSize) <= max(1e-9, abs(portfolio.baseSize) * 1e-9)
        let leverageMatches = counted.leverage == portfolio.leverage
        let matches = sizeMatches && leverageMatches && entryOff < 0.01 && marginOff < 0.1
        var fields = [
            "market_id": String(portfolio.marketId),
            "size_counted": String(counted.baseSize),
            "size_portfolio": String(portfolio.baseSize),
            "entry_counted": String(counted.entryPrice),
            "entry_portfolio": String(portfolio.entryPrice),
            "margin_counted": String(counted.marginUsd),
            "margin_portfolio": String(portfolio.marginUsd),
            "leverage_counted": counted.leverage.map { String($0) } ?? "",
            "leverage_portfolio": portfolio.leverage.map { String($0) } ?? "",
            "liquidation_estimate": String(counted.liquidationPrice),
            "liquidation_portfolio": String(portfolio.liquidationPrice),
            "entry_off_pct": String(format: "%.4f", entryOff),
            "margin_off_pct": String(format: "%.4f", marginOff),
            "liquidation_off_pct": String(format: "%.4f", liquidationOff),
        ]
        if let countedAt {
            fields["shown_ms"] = String(Int(Date().timeIntervalSince(countedAt) * 1000))
        }
        PerpsOperationLog.event("counted_position", outcome: matches ? "match" : "mismatch", fields: fields)
    }

    func notifyLifecycleChanged() {
        updateState({ _ in nil }) { [weak self] state in
            self?.sendEvent(.didUpdate(state))
        }
    }

    func reloadRequestedExtras(accountIndex: Int64) {
        let markets = lock.withLock { Array(requestedExtrasMarkets) }
        for marketId in markets {
            fetchMarketExtras(accountIndex: accountIndex, marketId: marketId, reason: "resolve")
        }
    }

    func fetchMarketExtras(accountIndex: Int64, marketId: Int64, reason: String, retryAfterOrderAccess: Bool = true) {
        Log.perps.d("extras fetch market=\(marketId) reason=\(reason)")
        let requestId = UUID()
        lock.withLock {
            marketExtrasRequestIds[marketId] = requestId
            if pendingByMarket[marketId]?.isPlacedLimitOrder == true {
                pendingByMarket[marketId]?.clearsAfterExtrasReload = true
            }
        }
        Task { [weak self] in
            guard let self else { return }
            async let trading = self.tradingSnapshotResult(marketId: marketId)
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
               await self.reissueReadOnlyToken()
            {
                self.fetchMarketExtras(
                    accountIndex: accountIndex,
                    marketId: marketId,
                    reason: "order_access",
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

    private func cachedExtras(marketId: Int64, accountIndex: Int64) -> PerpsMarketExtras? {
        lock.withLock {
            guard let entry = marketExtrasByMarket[marketId],
                  entry.accountIndex == accountIndex
            else { return nil }
            return entry.extras
        }
    }

    func tradingSnapshotResult(marketId: Int64) async -> Result<PerpsTradingSnapshot, Error> {
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

    internal func watchFocus() -> PerpsWatchFocus {
        guard case let .active(account) = currentWalletState() else { return .portfolio }
        guard account.positions.isEmpty, account.positionsLoaded, account.openOrders.isEmpty else { return .portfolio }
        let watchesOrders = lock.withLock {
            !pendingByMarket.isEmpty || !countedByMarket.isEmpty || marketExtrasByMarket.contains { marketId, entry in
                requestedExtrasMarkets.contains(marketId)
                    && entry.accountIndex == account.accountIndex
                    && !entry.extras.limitOrders.isEmpty
            }
        }
        return watchesOrders ? .portfolio : .idle
    }

    func applyPositionsTick(_ tick: PerpsAccountTick) {
        if case let .marks(marks) = tick {
            applyMarks(marks)
            return
        }
        guard case let .active(account) = currentWalletState() else { return }
        // A socket snapshot must not blank an existing position on its own: an empty list
        // during a reconnect blip would flash `.flat` (Long/Short) on a market the user
        // still holds. Defer to an authoritative REST read, which also reflects a genuine
        // full close a beat later.
        if tick.positions.isEmpty, !account.positions.isEmpty {
            refresh()
            return
        }
        applyRead(requestedAt: tick.requestedAt, showing: { current in
            guard var updated = current else { return nil }
            switch tick {
            case let .portfolio(snapshot):
                updated = Self.account(updated, holding: snapshot)
            case let .positions(positions, _):
                updated.positions = positions
                updated.positionsLoaded = true
            case .marks:
                return nil
            }
            return updated
        }, shown: { [weak self] before, after in
            guard let before else { return }
            self?.followPositionUpdate(after, over: before)
        })
    }

    func applyMarks(_ marks: [Int64: Double]) {
        var marked = false
        updateState { state in
            guard case var .active(account) = state, account.positions.contains(where: { marks[$0.marketId] != nil }) else { return nil }
            account.positions = account.positions.map { position in marks[position.marketId].map(position.marked(at:)) ?? position }
            marked = true
            return StateUpdate(newState: .active(account))
        } completion: { [weak self] state in
            guard marked else { return }
            self?.sendEvent(.didUpdate(state))
        }
    }

    func followPositionUpdate(_ updated: State.Account, over account: State.Account) {
        guard account.positionsLoaded else { return }
        guard Set(account.positions.map(\.marketId)) == Set(updated.positions.map(\.marketId)) else {
            updateState({ _ in nil }) { [weak self] _ in self?.refresh() }
            return
        }
        let moved = Self.marketsWithMovedPositions(
            before: Self.positionShapes(account.positions),
            after: Self.positionShapes(updated.positions)
        ).union(Self.marketsWithMovedOrders(before: account.openOrders, after: updated.openOrders))
        let toRefresh = lock.withLock { requestedExtrasMarkets.intersection(moved).sorted() }
        guard !toRefresh.isEmpty else { return }
        // The position moved on the venue, so a screen read that started before must not answer.
        service.invalidateSharedReads()
        for marketId in toRefresh {
            fetchMarketExtras(accountIndex: account.accountIndex, marketId: marketId, reason: "positions_moved")
        }
    }

    internal static func marketsWithMovedOrders(
        before: [PerpsPortfolioOrder],
        after: [PerpsPortfolioOrder]
    ) -> Set<Int64> {
        func orders(_ orders: [PerpsPortfolioOrder], marketId: Int64) -> [PerpsLimitOrderSummary] {
            orders.filter { $0.marketId == marketId }.map(\.order).sorted { $0.orderIndex < $1.orderIndex }
        }
        return Set(before.map(\.marketId) + after.map(\.marketId)).filter { marketId in
            orders(before, marketId: marketId) != orders(after, marketId: marketId)
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

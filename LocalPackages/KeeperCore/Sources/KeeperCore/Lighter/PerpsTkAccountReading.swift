import Foundation
import PerpsModels
import TKLogging
import TKPerpsAPI

struct PerpsPortfolioRead: Sendable {
    let portfolio: Components.Schemas.Portfolio
    let requestedAt: TimeInterval
}

final class PerpsTkAccountReading: PerpsAccountReading {
    private let api: PerpsAPI
    private let tradingScreenReads: PerpsTradingScreenReads
    /// A resolve and the positions watch both read the portfolio as a screen opens, a few hundred
    /// ms apart, and share one request. Kept below the poll interval, so a poll never answers itself;
    /// the realtime watch drops it after every wake, so an event's read never reuses an older one.
    private let portfolioReads: PerpsSharedReads<String, PerpsPortfolioRead>
    private let liveFeed: PerpsLiveFeed
    private let markPrices: @Sendable (Set<Int64>) -> AsyncStream<[Int64: Double]>
    private let isRealtimeEnabled: @Sendable () -> Bool
    private let unlistedPositions: PerpsUnlistedPositionsReport?

    init(
        api: PerpsAPI,
        tradingScreenReads: PerpsTradingScreenReads = PerpsTradingScreenReads(),
        portfolioReads: PerpsSharedReads<String, PerpsPortfolioRead> = .init(
            reuseWindow: PerpsPositionsCadence.live.pollInterval / 2
        ),
        liveFeed: PerpsLiveFeed = PerpsLiveFeed(signals: { AsyncStream { $0.finish() } }),
        markPrices: @escaping @Sendable (Set<Int64>) -> AsyncStream<[Int64: Double]> = { _ in AsyncStream { $0.finish() } },
        isRealtimeEnabled: @escaping @Sendable () -> Bool = { false },
        unlistedPositions: PerpsUnlistedPositionsReport? = nil
    ) {
        self.unlistedPositions = unlistedPositions
        self.api = api
        self.tradingScreenReads = tradingScreenReads
        self.portfolioReads = portfolioReads
        self.liveFeed = liveFeed
        self.markPrices = markPrices
        self.isRealtimeEnabled = isRealtimeEnabled
    }

    func status(wallet: Wallet) async -> PerpsAccountStatus {
        do {
            let account = try await api.account(walletId: walletId(wallet))
            guard let index = account.account_index else {
                guard let l1Address = account.l1_address else { return .unbound }
                return .noAccount(ethAddress: l1Address)
            }
            return .account(
                accountIndex: Int64(index),
                hasTradingKey: account.has_l2_key,
                hasReadOnlyToken: account.has_ro_token,
                availableBalance: account.available_balance,
                collateral: account.collateral,
                equity: account.equity
            )
        } catch {
            return .unavailable(reason: "\(error)")
        }
    }

    func portfolio(wallet: Wallet) async throws -> PerpsAccountSnapshot? {
        let read = try await sharedPortfolio(walletId: walletId(wallet))
        let balance = read.portfolio.balance
        let snapshot = snapshot(read, openOrders: mappedOrders(read.portfolio.open_orders), source: "portfolio read")
        Log.perps.i("portfolio read balance=\(balance?.available_balance ?? "nil") collateral=\(balance?.collateral ?? "nil") \(Self.positionsLine(snapshot.positions)) orders=\(Self.ordersLine(snapshot.openOrders))")
        return snapshot
    }

    func invalidateSharedReads() {
        portfolioReads.invalidate()
        tradingScreenReads.invalidate()
    }

    func watchPositions(
        wallet: Wallet,
        pollInterval: TimeInterval,
        focus: @escaping @Sendable () -> PerpsWatchFocus,
        onUpdate: @escaping @Sendable (PerpsAccountTick) -> Void,
        onInterrupted: @escaping @Sendable () -> Void
    ) -> PerpsPositionsWatch {
        guard isRealtimeEnabled() else {
            Log.perps.i("positions watch: polling every \(pollInterval) s, realtime off")
            return pollPositions(wallet: wallet, pollInterval: pollInterval, focus: focus, onUpdate: onUpdate, onInterrupted: onInterrupted)
        }
        let task = Task { [weak self] in
            guard let self else { return }
            func interrupt() {
                guard !Task.isCancelled else { return }
                onInterrupted()
            }
            let walletId: String
            do {
                walletId = try self.walletId(wallet)
            } catch {
                Log.perps.w("positions poll unavailable — \(error)")
                interrupt()
                return
            }
            let marked = PerpsMarkedTicks(markPrices: self.markPrices, emit: onUpdate)
            let changes = await self.liveFeed.listen([.account, .anyMarket])
            var failures = 0
            var lastLogged: String?
            while !Task.isCancelled {
                let watched = focus()
                do {
                    switch watched {
                    case .idle:
                        break
                    case .portfolio:
                        let read = try await self.readTick(walletId: walletId, lastLogged: lastLogged)
                        lastLogged = read.logged
                        failures = 0
                        if !Task.isCancelled {
                            await marked.follow(read.tick)
                        }
                    }
                } catch {
                    // Cancellation reaches here as a thrown error too, and it is not a failure:
                    // counting it would back off a watch that is going away and would fire
                    // onInterrupted into an owner that has already moved on.
                    if Task.isCancelled { return }
                    failures += 1
                    if failures == 1 {
                        Log.perps.w("positions poll failed — \(error)")
                        interrupt()
                    }
                }
                let retry = Self.retryDelay(afterFailures: failures)
                let changed = if failures > 0 {
                    await changes.next(pollAfter: retry, liveTimeout: retry)
                } else if watched == .idle {
                    await changes.next(pollAfter: pollInterval, liveTimeout: pollInterval)
                } else {
                    await changes.next()
                }
                if !Task.isCancelled, changed || watched != .idle {
                    Log.perps.i("positions watch woke on \(changed ? "a change" : "its timer")")
                }
                self.portfolioReads.invalidate()
            }
            await marked.stop()
        }
        return PerpsPositionsWatch(followsCadence: false) { task.cancel() }
    }

    private func pollPositions(
        wallet: Wallet,
        pollInterval: TimeInterval,
        focus: @escaping @Sendable () -> PerpsWatchFocus,
        onUpdate: @escaping @Sendable (PerpsAccountTick) -> Void,
        onInterrupted: @escaping @Sendable () -> Void
    ) -> PerpsPositionsWatch {
        let task = Task { [weak self] in
            guard let self else { return }
            func emit(_ tick: PerpsAccountTick) {
                guard !Task.isCancelled else { return }
                onUpdate(tick)
            }
            func interrupt() {
                guard !Task.isCancelled else { return }
                onInterrupted()
            }
            let walletId: String
            do {
                walletId = try self.walletId(wallet)
            } catch {
                Log.perps.w("positions poll unavailable — \(error)")
                interrupt()
                return
            }
            var failures = 0
            var lastLogged: String?
            while !Task.isCancelled {
                do {
                    switch focus() {
                    case .idle:
                        break
                    case .portfolio:
                        let read = try await self.readTick(walletId: walletId, lastLogged: lastLogged)
                        lastLogged = read.logged
                        failures = 0
                        emit(read.tick)
                    }
                } catch {
                    // Cancellation reaches here as a thrown error too, and it is not a failure:
                    // counting it would back off a watch that is going away and would fire
                    // onInterrupted into an owner that has already moved on.
                    if Task.isCancelled { return }
                    failures += 1
                    if failures == 1 {
                        Log.perps.w("positions poll failed — \(error)")
                        interrupt()
                    }
                }
                try? await Task.sleep(nanoseconds: Self.pollDelayNanoseconds(
                    pollInterval: pollInterval,
                    afterFailures: failures
                ))
            }
        }
        return PerpsPositionsWatch { task.cancel() }
    }

    static func pollDelayNanoseconds(pollInterval: TimeInterval, afterFailures failures: Int) -> UInt64 {
        let interval = UInt64(max(pollInterval, 0.5) * 1_000_000_000)
        return interval << UInt64(min(max(failures, 0), 4))
    }

    static func retryDelay(afterFailures failures: Int) -> TimeInterval {
        TimeInterval(2 << min(max(failures, 1), 4))
    }

    func tradingSnapshot(
        wallet: Wallet,
        marketId: Int64,
        positionId: String?
    ) async throws -> PerpsTradingSnapshot {
        let walletId = try walletId(wallet)
        let screen = try await tradingScreenReads.tradingScreen(api: api, walletId: walletId, marketId: marketId)
        let flags = PerpsBackendMapping.tradingFlags(screen)
        if PerpsBackendMapping.ordersReadable(screen) {
            let marketOrders = screen.open_orders?.filter { $0.market_index.map(Int64.init) == marketId }
            let foreignOrders = (screen.open_orders ?? []).filter { $0.market_index.map(Int64.init) != marketId }
            if !foreignOrders.isEmpty {
                let markets = foreignOrders.map { $0.market_index.map(String.init) ?? "nil" }.joined(separator: ",")
                Log.perps.w("trading screen for market \(marketId) served \(foreignOrders.count) orders of markets \(markets)")
            }
            return PerpsTradingSnapshot(flags: flags, orders: PerpsActiveOrders(
                limitOrders: PerpsBackendMapping.limitOrders(marketOrders, market: screen.market),
                triggerOrders: PerpsBackendMapping.triggerOrders(marketOrders)
            ))
        }
        if let detail = try? await openPositionDetail(
            walletId: walletId,
            positionId: positionId ?? PerpsPlannerMapping.tkPositionId(marketId: marketId)
        ),
            detail.auto_close_known == true
        {
            let side = PerpsBackendMapping.tradeSide(detail.position?.side)
            return PerpsTradingSnapshot(flags: flags, orders: PerpsActiveOrders(
                limitOrders: [],
                triggerOrders: PerpsBackendMapping.triggerOrders(
                    autoClose: detail.auto_close?.value1,
                    side: side
                )
            ))
        }
        Log.perps.w("orders unknown market=\(marketId) — open_orders=\(screen.open_orders.map { "\($0.count)" } ?? "nil") cancel_enabled=\(screen.flags?.cancel_enabled.map { "\($0)" } ?? "nil")")
        return PerpsTradingSnapshot(flags: flags, orders: nil)
    }
}

private extension PerpsTkAccountReading {
    func sharedPortfolio(walletId: String) async throws -> PerpsPortfolioRead {
        try await portfolioReads.value(for: walletId) { [api] in
            let requestedAt = ProcessInfo.processInfo.systemUptime
            return try await PerpsPortfolioRead(portfolio: api.portfolio(walletId: walletId), requestedAt: requestedAt)
        }
    }

    func readTick(
        walletId: String,
        lastLogged: String?
    ) async throws -> (tick: PerpsAccountTick, logged: String) {
        let tick: PerpsAccountTick
        let logged: String
        do {
            let read = try await sharedPortfolio(walletId: walletId)
            let openOrders = PerpsBackendMapping.portfolioOrders(read.portfolio.open_orders)
            let snapshot = snapshot(read, openOrders: openOrders, source: "positions poll")
            tick = .portfolio(snapshot)
            logged = "\(Self.positionsLine(snapshot.positions)) orders=\(Self.ordersLine(snapshot.openOrders))"
        } catch let error as PerpsAPIError where error.isReadOnlyTokenUnavailable {
            let requestedAt = ProcessInfo.processInfo.systemUptime
            let received = try await api.listOpenPositions(walletId: walletId).positions ?? []
            let positions = mappedPositions(received, source: "positions poll")
            tick = .positions(positions, requestedAt: requestedAt)
            logged = "\(Self.positionsLine(positions)) orders=unknown"
        }
        if logged != lastLogged {
            Log.perps.i("positions poll \(logged)")
        }
        return (tick, logged)
    }

    func snapshot(
        _ read: PerpsPortfolioRead,
        openOrders: [PerpsPortfolioOrder],
        source: String
    ) -> PerpsAccountSnapshot {
        let balance = read.portfolio.balance
        return PerpsAccountSnapshot(
            availableBalance: balance?.available_balance ?? "0",
            collateral: balance?.collateral,
            equity: balance?.equity,
            transferableBalance: balance?.transferable_balance,
            positions: mappedPositions(read.portfolio.positions ?? [], source: source),
            openOrders: openOrders,
            requestedAt: read.requestedAt
        )
    }

    static func ordersLine(_ orders: [PerpsPortfolioOrder]) -> String {
        "\(orders.map { "\($0.marketId):\($0.order.side):\($0.order.remainingBaseAmount)@\($0.order.limitPrice)" })"
    }

    static func positionsLine(_ positions: [PerpsPositionSummary]) -> String {
        let summaries = positions.map {
            "\($0.marketId):\($0.side):\($0.baseSize)@\($0.entryPrice) margin=\($0.marginUsd) liq=\($0.liquidationPrice)"
        }
        return "\(positions.count) \(summaries)"
    }

    func mappedPositions(
        _ received: [Components.Schemas.OpenPosition],
        source: String
    ) -> [PerpsPositionSummary] {
        let mapped = received.compactMap(PerpsBackendMapping.position)
        if let unlistedPositions, !mapped.isEmpty {
            Task { await unlistedPositions.check(mapped) }
        }
        guard mapped.count != received.count else { return mapped }
        let dropped = received
            .filter { PerpsBackendMapping.position($0) == nil }
            .map { "market=\($0.market_index.map(String.init) ?? "nil") symbol=\($0.symbol ?? "nil") size=\($0.size ?? "nil")" }
            .joined(separator: ", ")
        Log.perps.w("\(source) dropped \(received.count - mapped.count) position(s) — \(dropped)")
        return mapped
    }

    func mappedOrders(_ received: [Components.Schemas.PortfolioOrder]?) -> [PerpsPortfolioOrder] {
        let mapped = PerpsBackendMapping.portfolioOrders(received)
        let receivedCount = received?.count ?? 0
        if mapped.count != receivedCount {
            Log.perps.w("portfolio read dropped \(receivedCount - mapped.count) order(s) of \(receivedCount)")
        }
        return mapped
    }

    func walletId(_ wallet: Wallet) throws -> String {
        guard let walletId = wallet.multichainWalletState?.walletId, !walletId.isEmpty else {
            throw PerpsAccountReadError.missingWalletId
        }
        return walletId
    }

    func openPositionDetail(
        walletId: String,
        positionId: String
    ) async throws -> Components.Schemas.OpenPositionDetail? {
        do {
            return try await api.getOpenPosition(walletId: walletId, id: positionId)
        } catch PerpsAPIError.notFound {
            return nil
        }
    }
}

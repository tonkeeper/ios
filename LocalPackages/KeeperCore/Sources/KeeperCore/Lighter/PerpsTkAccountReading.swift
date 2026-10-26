import Foundation
import PerpsModels
import TKLogging
import TKPerpsAPI

final class PerpsTkAccountReading: PerpsAccountReading {
    private let api: PerpsAPI

    init(
        api: PerpsAPI
    ) {
        self.api = api
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
        let portfolio = try await api.portfolio(walletId: walletId(wallet))
        let balance = portfolio.balance
        let positions = mappedPositions(portfolio.positions ?? [], source: "portfolio read")
        let openOrders = mappedOrders(portfolio.open_orders)
        Log.perps.i("portfolio read balance=\(balance?.available_balance ?? "nil") collateral=\(balance?.collateral ?? "nil") \(Self.positionsLine(positions)) orders=\(Self.ordersLine(openOrders))")
        return PerpsAccountSnapshot(
            availableBalance: balance?.available_balance ?? "0",
            collateral: balance?.collateral,
            equity: balance?.equity,
            transferableBalance: balance?.transferable_balance,
            positions: positions,
            openOrders: openOrders
        )
    }

    func watchPositions(
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
                    case let .orders(ids):
                        let progress = try await self.orderProgress(walletId: walletId, ids: ids)
                        failures = 0
                        emit(.orders(progress))
                    case let .positionsAndOrders(ids):
                        async let positionsRead = self.readPositions(walletId: walletId, lastLogged: lastLogged)
                        async let progressRead = self.orderProgress(walletId: walletId, ids: ids)
                        let read = try await positionsRead
                        lastLogged = read.logged
                        do {
                            let progress = try await progressRead
                            failures = 0
                            emit(.positionsAndOrders(read.positions, progress, openOrders: read.openOrders))
                        } catch let error as PerpsAPIError where error.isReadOnlyTokenUnavailable {
                            failures = 0
                            emit(.positions(read.positions, openOrders: read.openOrders))
                        } catch {
                            // Keep the successful position read visible even when the
                            // auxiliary order-progress read is temporarily unavailable.
                            emit(.positions(read.positions, openOrders: read.openOrders))
                            throw error
                        }
                    case .positions:
                        let read = try await self.readPositions(walletId: walletId, lastLogged: lastLogged)
                        lastLogged = read.logged
                        failures = 0
                        emit(.positions(read.positions, openOrders: read.openOrders))
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

    func tradingSnapshot(
        wallet: Wallet,
        marketId: Int64,
        positionId: String?
    ) async throws -> PerpsTradingSnapshot {
        let walletId = try walletId(wallet)
        let screen = try await api.tradingScreen(walletId: walletId, marketId: marketId)
        let flags = PerpsBackendMapping.tradingFlags(screen.flags)
        if PerpsBackendMapping.ordersReadable(screen) {
            return PerpsTradingSnapshot(flags: flags, orders: PerpsActiveOrders(
                limitOrders: PerpsBackendMapping.limitOrders(screen.open_orders),
                triggerOrders: PerpsBackendMapping.triggerOrders(screen.open_orders)
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
    func readPositions(
        walletId: String,
        lastLogged: String?
    ) async throws -> (positions: [PerpsPositionSummary], openOrders: [PerpsPortfolioOrder]?, logged: String) {
        let received: [Components.Schemas.OpenPosition]
        let openOrders: [PerpsPortfolioOrder]?
        do {
            let portfolio = try await api.portfolio(walletId: walletId)
            received = portfolio.positions ?? []
            openOrders = PerpsBackendMapping.portfolioOrders(portfolio.open_orders)
        } catch let error as PerpsAPIError where error.isReadOnlyTokenUnavailable {
            received = try await api.listOpenPositions(walletId: walletId).positions ?? []
            openOrders = nil
        }
        let positions = mappedPositions(received, source: "positions poll")
        let logged = "\(Self.positionsLine(positions)) orders=\(openOrders.map(Self.ordersLine) ?? "unknown")"
        if logged != lastLogged {
            Log.perps.i("positions poll \(logged)")
        }
        return (positions, openOrders, logged)
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
        guard mapped.count != received.count else { return mapped }
        let dropped = received
            .filter { PerpsBackendMapping.position($0) == nil }
            .map { "market=\($0.market_index.map(String.init) ?? "nil") symbol=\($0.symbol ?? "nil") size=\($0.size ?? "nil")" }
            .joined(separator: ", ")
        Log.perps.w("\(source) dropped \(received.count - mapped.count) position(s) — \(dropped)")
        return mapped
    }

    func mappedOrders(_ received: [Components.Schemas.Order]?) -> [PerpsPortfolioOrder] {
        let mapped = PerpsBackendMapping.portfolioOrders(received)
        let receivedCount = received?.count ?? 0
        if mapped.count != receivedCount {
            Log.perps.w("portfolio read dropped \(receivedCount - mapped.count) order(s) of \(receivedCount)")
        }
        return mapped
    }

    func orderProgress(walletId: String, ids: [String]) async throws -> [PerpsOrderProgress] {
        var progress = [PerpsOrderProgress]()
        for id in ids {
            do {
                let detail = try await api.getOrder(walletId: walletId, id: id)
                progress.append(PerpsOrderProgress(
                    id: id,
                    isResting: detail.resting ?? false,
                    filledBaseAmount: PerpsMarketMath.double(detail.order?.filled_base)
                ))
            } catch PerpsAPIError.notFound {
                progress.append(PerpsOrderProgress(id: id, isResting: false, filledBaseAmount: 0))
            }
        }
        return progress
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

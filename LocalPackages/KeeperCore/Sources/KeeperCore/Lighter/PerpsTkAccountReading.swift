import Foundation
import TKLogging
import TKPerpsAPI

final class PerpsTkAccountReading: PerpsAccountReading {
    private static let positionsPollIntervalNanoseconds: UInt64 = 2_000_000_000

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
            return .account(accountIndex: Int64(index))
        } catch {
            return .unavailable(reason: "\(error)")
        }
    }

    func portfolio(wallet: Wallet) async throws -> PerpsAccountSnapshot? {
        let walletId = try walletId(wallet)
        async let screen = api.portfolioScreen(walletId: walletId)
        async let page = api.listOpenPositions(walletId: walletId)
        return try await PerpsBackendMapping.snapshot(
            availableBalance: screen.balance?.available_balance ?? "0",
            positions: page.positions
        )
    }

    func watchPositions(
        wallet: Wallet,
        onUpdate: @escaping @Sendable ([PerpsPositionSummary]) -> Void,
        onInterrupted: @escaping @Sendable () -> Void
    ) -> PerpsPositionsWatch {
        let task = Task { [weak self] in
            guard let self else { return }
            let walletId: String
            do {
                walletId = try self.walletId(wallet)
            } catch {
                Log.w("🪵 Perps: positions poll unavailable — \(error)")
                onInterrupted()
                return
            }
            var failures = 0
            while !Task.isCancelled {
                do {
                    let page = try await api.listOpenPositions(walletId: walletId)
                    failures = 0
                    onUpdate((page.positions ?? []).compactMap(PerpsBackendMapping.position))
                } catch {
                    failures += 1
                    if failures == 1 {
                        Log.w("🪵 Perps: positions poll failed — \(error)")
                        onInterrupted()
                    }
                }
                try? await Task.sleep(nanoseconds: Self.pollDelayNanoseconds(afterFailures: failures))
            }
        }
        return PerpsPositionsWatch { task.cancel() }
    }

    static func pollDelayNanoseconds(afterFailures failures: Int) -> UInt64 {
        positionsPollIntervalNanoseconds << UInt64(min(max(failures, 0), 4))
    }

    func tradingSnapshot(
        wallet: Wallet,
        marketId: Int64,
        positionId: String?
    ) async throws -> PerpsTradingSnapshot {
        let walletId = try walletId(wallet)
        let screen = try await api.tradingScreen(walletId: walletId, marketId: marketId)
        let flags = PerpsBackendMapping.tradingFlags(screen.flags)
        if PerpsBackendMapping.ordersVisible(screen.flags) {
            return PerpsTradingSnapshot(flags: flags, orders: PerpsActiveOrders(
                limitOrders: PerpsBackendMapping.limitOrders(screen.open_orders),
                triggerOrders: PerpsBackendMapping.triggerOrders(screen.open_orders)
            ))
        }
        if let detail = try await openPositionDetail(
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
        Log.w("🪵 Perps: orders unknown market=\(marketId) — no readable book and no known auto-close")
        return PerpsTradingSnapshot(flags: flags, orders: nil)
    }

    func recentActivity(
        wallet: Wallet,
        marketId: Int64,
        limit: Int
    ) async throws -> [PerpsActivityItem] {
        let walletId = try walletId(wallet)
        let limit = max(limit, 1)
        let page = try await api.activity(
            walletId: walletId,
            marketId: marketId,
            limit: limit
        )
        return Array((page.items ?? []).compactMap(PerpsBackendMapping.activity).prefix(limit))
    }
}

private extension PerpsTkAccountReading {
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

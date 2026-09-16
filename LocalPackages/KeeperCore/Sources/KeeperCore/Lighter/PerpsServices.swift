import ChainKit
import Foundation

public struct PerpsPositionsWatch {
    private let onCancel: @Sendable () -> Void

    public init(onCancel: @escaping @Sendable () -> Void) {
        self.onCancel = onCancel
    }

    public func cancel() {
        onCancel()
    }
}

public struct PerpsTransactionUpdatesWatch {
    private let onCancel: @Sendable () -> Void

    public init(onCancel: @escaping @Sendable () -> Void) {
        self.onCancel = onCancel
    }

    public func cancel() {
        onCancel()
    }
}

protocol PerpsAccountReading: AnyObject {
    func status(wallet: Wallet) async -> LighterPerpsStatus

    func portfolio(wallet: Wallet, accountIndex: Int64) async throws -> PerpsPortfolio?

    func watchPositions(
        wallet: Wallet,
        accountIndex: Int64,
        onUpdate: @escaping @Sendable ([PerpsPositionSummary]) -> Void,
        onReconnecting: @escaping @Sendable () -> Void
    ) -> PerpsPositionsWatch

    func watchTransactionUpdates(
        wallet: Wallet,
        onUpdate: @escaping @Sendable () -> Void,
        onReconnecting: @escaping @Sendable () -> Void
    ) async throws -> PerpsTransactionUpdatesWatch?

    func activeTriggerOrders(wallet: Wallet, accountIndex: Int64, marketId: Int64) async throws -> [PerpsTriggerOrderSummary]

    func activeMarketOrders(wallet: Wallet, accountIndex: Int64, marketId: Int64) async throws -> PerpsActiveOrders

    func recentActivity(wallet: Wallet, accountIndex: Int64, marketId: Int64, limit: Int) async throws -> [PerpsActivityItem]
}

extension PerpsAccountReading {
    func watchTransactionUpdates(
        wallet _: Wallet,
        onUpdate _: @escaping @Sendable () -> Void,
        onReconnecting _: @escaping @Sendable () -> Void
    ) async throws -> PerpsTransactionUpdatesWatch? {
        nil
    }

    func activeMarketOrders(wallet: Wallet, accountIndex: Int64, marketId: Int64) async throws -> PerpsActiveOrders {
        try PerpsActiveOrders(
            limitOrders: [],
            triggerOrders: await activeTriggerOrders(wallet: wallet, accountIndex: accountIndex, marketId: marketId)
        )
    }
}

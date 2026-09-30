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

public struct PerpsAccountSnapshot: Sendable, Equatable {
    public let availableBalance: String
    public let positions: [PerpsPositionSummary]

    public init(availableBalance: String, positions: [PerpsPositionSummary] = []) {
        self.availableBalance = availableBalance
        self.positions = positions
    }
}

protocol PerpsAccountReading: AnyObject {
    func status(wallet: Wallet) async -> PerpsAccountStatus

    func portfolio(wallet: Wallet) async throws -> PerpsAccountSnapshot?

    func watchPositions(
        wallet: Wallet,
        onUpdate: @escaping @Sendable ([PerpsPositionSummary]) -> Void,
        onInterrupted: @escaping @Sendable () -> Void
    ) -> PerpsPositionsWatch

    func tradingSnapshot(wallet: Wallet, marketId: Int64, positionId: String?) async throws -> PerpsTradingSnapshot

    func recentActivity(wallet: Wallet, marketId: Int64, limit: Int) async throws -> [PerpsActivityItem]
}

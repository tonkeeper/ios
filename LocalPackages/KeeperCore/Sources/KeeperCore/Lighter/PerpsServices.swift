import Foundation
import PerpsModels

public struct PerpsPositionsWatch: Sendable {
    public let followsCadence: Bool
    private let onCancel: @Sendable () -> Void

    public init(followsCadence: Bool = true, onCancel: @escaping @Sendable () -> Void) {
        self.followsCadence = followsCadence
        self.onCancel = onCancel
    }

    public func cancel() {
        onCancel()
    }
}

/// The store runs one watch at the fastest cadence its subscribers asked for.
extension PerpsPositionsCadence {
    var pollInterval: TimeInterval {
        switch self {
        case .live: 2
        case .ambient: 10
        }
    }
}

public struct PerpsAccountSnapshot: Sendable, Equatable {
    public let availableBalance: String
    public let collateral: String
    public let equity: String
    public let transferableBalance: String?
    public let positions: [PerpsPositionSummary]
    public let openOrders: [PerpsPortfolioOrder]
    public let requestedAt: TimeInterval?

    public init(
        availableBalance: String,
        collateral: String? = nil,
        equity: String? = nil,
        transferableBalance: String? = nil,
        positions: [PerpsPositionSummary] = [],
        openOrders: [PerpsPortfolioOrder] = [],
        requestedAt: TimeInterval? = nil
    ) {
        self.availableBalance = availableBalance
        self.collateral = collateral ?? availableBalance
        self.equity = equity ?? availableBalance
        self.transferableBalance = transferableBalance
        self.positions = positions
        self.openOrders = openOrders
        self.requestedAt = requestedAt
    }
}

@frozen public enum PerpsWatchFocus: Sendable, Equatable {
    case idle
    case portfolio
}

@frozen public enum PerpsAccountTick: Sendable {
    case portfolio(PerpsAccountSnapshot)
    case positions([PerpsPositionSummary], requestedAt: TimeInterval? = nil)
    case marks([Int64: Double])
}

protocol PerpsAccountReading: AnyObject {
    func status(wallet: Wallet) async -> PerpsAccountStatus

    func portfolio(wallet: Wallet) async throws -> PerpsAccountSnapshot?

    /// Reads after this never share one that started before it.
    func invalidateSharedReads()

    func watchPositions(
        wallet: Wallet,
        pollInterval: TimeInterval,
        focus: @escaping @Sendable () -> PerpsWatchFocus,
        onUpdate: @escaping @Sendable (PerpsAccountTick) -> Void,
        onInterrupted: @escaping @Sendable () -> Void
    ) -> PerpsPositionsWatch

    func tradingSnapshot(wallet: Wallet, marketId: Int64, positionId: String?) async throws -> PerpsTradingSnapshot
}

extension PerpsAccountReading {
    /// A reader that shares no reads has nothing to drop.
    func invalidateSharedReads() {}
}

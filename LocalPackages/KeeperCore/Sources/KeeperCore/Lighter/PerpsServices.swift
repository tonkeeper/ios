import Foundation
import PerpsModels

public struct PerpsPositionsWatch: Sendable {
    private let onCancel: @Sendable () -> Void

    public init(onCancel: @escaping @Sendable () -> Void) {
        self.onCancel = onCancel
    }

    public func cancel() {
        onCancel()
    }
}

/// The store runs one watch at the fastest cadence its subscribers asked for.
extension PerpsPositionsCadence {
    var pollInterval: TimeInterval {
        10
    }
}

public struct PerpsAccountSnapshot: Sendable, Equatable {
    public let availableBalance: String
    public let collateral: String
    public let equity: String
    public let transferableBalance: String?
    public let positions: [PerpsPositionSummary]
    public let openOrders: [PerpsPortfolioOrder]

    public init(
        availableBalance: String,
        collateral: String? = nil,
        equity: String? = nil,
        transferableBalance: String? = nil,
        positions: [PerpsPositionSummary] = [],
        openOrders: [PerpsPortfolioOrder] = []
    ) {
        self.availableBalance = availableBalance
        self.collateral = collateral ?? availableBalance
        self.equity = equity ?? availableBalance
        self.transferableBalance = transferableBalance
        self.positions = positions
        self.openOrders = openOrders
    }
}

@frozen public enum PerpsWatchFocus: Sendable, Equatable {
    case idle
    case positions
    case orders([String])
    case positionsAndOrders([String])
}

public struct PerpsOrderProgress: Sendable, Equatable {
    public let id: String
    public let isResting: Bool
    public let filledBaseAmount: Double

    public init(id: String, isResting: Bool, filledBaseAmount: Double) {
        self.id = id
        self.isResting = isResting
        self.filledBaseAmount = filledBaseAmount
    }
}

@frozen public enum PerpsAccountTick: Sendable {
    case positions([PerpsPositionSummary], openOrders: [PerpsPortfolioOrder]? = nil)
    case orders([PerpsOrderProgress])
    case positionsAndOrders([PerpsPositionSummary], [PerpsOrderProgress], openOrders: [PerpsPortfolioOrder]? = nil)
}

protocol PerpsAccountReading: AnyObject {
    func status(wallet: Wallet) async -> PerpsAccountStatus

    func portfolio(wallet: Wallet) async throws -> PerpsAccountSnapshot?

    func watchPositions(
        wallet: Wallet,
        pollInterval: TimeInterval,
        focus: @escaping @Sendable () -> PerpsWatchFocus,
        onUpdate: @escaping @Sendable (PerpsAccountTick) -> Void,
        onInterrupted: @escaping @Sendable () -> Void
    ) -> PerpsPositionsWatch

    func tradingSnapshot(wallet: Wallet, marketId: Int64, positionId: String?) async throws -> PerpsTradingSnapshot
}

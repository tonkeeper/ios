import Foundation
import PerpsModels

public enum PerpsRootAccountState {
    case resolving
    case inactive
    case active(Portfolio)

    public struct Portfolio {
        public let accountIndex: Int64
        public let balanceText: String
        public let positions: [PerpsPositionRowItem]
        public let positionsTotal: PerpsPositionsTotal?
        public let limitOrders: [PerpsLimitOrderRowItem]

        public init(
            accountIndex: Int64,
            balanceText: String,
            positions: [PerpsPositionRowItem],
            positionsTotal: PerpsPositionsTotal?,
            limitOrders: [PerpsLimitOrderRowItem] = []
        ) {
            self.accountIndex = accountIndex
            self.balanceText = balanceText
            self.positions = positions
            self.positionsTotal = positionsTotal
            self.limitOrders = limitOrders
        }
    }

    public var isActive: Bool {
        if case .active = self { true } else { false }
    }

    public var isResolving: Bool {
        if case .resolving = self { true } else { false }
    }

    public var portfolio: Portfolio? {
        if case let .active(portfolio) = self { portfolio } else { nil }
    }
}

public enum PerpsRootMarketsState {
    case loading
    case loaded(items: [PerpsMarketRowItem], isLoadingNextPage: Bool)
    case failed(String)
}

import Foundation

public struct StakingRewardRowState: Equatable, Identifiable {
    public let id: String
    public let amount: String
    public let apy: String
    public let date: String

    public init(id: String, amount: String, apy: String, date: String) {
        self.id = id
        self.amount = amount
        self.apy = apy
        self.date = date
    }
}

public struct StakingRewardsHistorySectionState: Equatable {
    public let total: String
    public let rows: [StakingRewardRowState]

    public init(total: String, rows: [StakingRewardRowState]) {
        self.total = total
        self.rows = rows
    }
}

public struct StakingRewardsHistoryState: Equatable {
    public enum Content: Equatable {
        case loading
        case rows([StakingRewardRowState], isLoadingMore: Bool, isLoadMoreFailed: Bool)
        case failed
    }

    public struct Total: Equatable {
        public let amount: String
        public let fiat: String

        public init(amount: String, fiat: String) {
            self.amount = amount
            self.fiat = fiat
        }
    }

    public let total: Total?
    public let periods: [String]
    public let selectedPeriodIndex: Int
    public let content: Content

    public init(total: Total?, periods: [String], selectedPeriodIndex: Int, content: Content) {
        self.total = total
        self.periods = periods
        self.selectedPeriodIndex = selectedPeriodIndex
        self.content = content
    }
}

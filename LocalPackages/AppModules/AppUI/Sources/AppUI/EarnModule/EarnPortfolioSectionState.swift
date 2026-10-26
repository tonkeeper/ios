import TKUIKit

public struct EarnPortfolioSectionState: Equatable {
    public let totalBalance: String
    public let isStale: Bool
    public let rows: [AssetBalanceRowCellContent]

    public init(totalBalance: String, isStale: Bool, rows: [AssetBalanceRowCellContent]) {
        self.totalBalance = totalBalance
        self.isStale = isStale
        self.rows = rows
    }
}

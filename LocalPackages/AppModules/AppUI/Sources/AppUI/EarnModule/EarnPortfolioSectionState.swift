import TKUIKit

public struct EarnPortfolioSectionState: Equatable {
    public let totalBalance: String
    public let isStale: Bool
    public let rows: [AssetBalanceRowCellContent]
    public let hiddenRows: [AssetBalanceRowCellContent]
    public let limit: WalletSectionLimit

    public init(
        totalBalance: String,
        isStale: Bool,
        rows: [AssetBalanceRowCellContent],
        hiddenRows: [AssetBalanceRowCellContent] = [],
        limit: WalletSectionLimit = .initial
    ) {
        self.totalBalance = totalBalance
        self.isStale = isStale
        self.rows = rows
        self.hiddenRows = hiddenRows
        self.limit = limit
    }

    public func limited(to limit: WalletSectionLimit) -> EarnPortfolioSectionState {
        let allRows = rows + hiddenRows
        return EarnPortfolioSectionState(
            totalBalance: totalBalance,
            isStale: isStale,
            rows: Array(allRows.prefix(limit.count)),
            hiddenRows: Array(allRows.dropFirst(limit.count)),
            limit: limit
        )
    }
}

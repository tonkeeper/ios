import Foundation

public struct PerpsAccount {
    public let accountIndex: Int64
    public let availableBalance: String
    public let collateral: String
    public let equity: String
    public let transferableBalance: String?
    public var positions: [PerpsPositionSummary]
    public var openOrders: [PerpsPortfolioOrder]
    public var positionsLoaded: Bool
    public let hasTradingKey: Bool
    public var hasReadOnlyToken: Bool
    public let needsActivation: Bool

    public init(
        accountIndex: Int64,
        availableBalance: String,
        collateral: String? = nil,
        equity: String? = nil,
        transferableBalance: String? = nil,
        positions: [PerpsPositionSummary] = [],
        openOrders: [PerpsPortfolioOrder] = [],
        positionsLoaded: Bool = true,
        hasTradingKey: Bool = true,
        hasReadOnlyToken: Bool = true,
        needsActivation: Bool = false
    ) {
        self.accountIndex = accountIndex
        self.availableBalance = availableBalance
        self.collateral = collateral ?? availableBalance
        self.equity = equity ?? availableBalance
        self.transferableBalance = transferableBalance
        self.positions = positions
        self.openOrders = openOrders
        self.positionsLoaded = positionsLoaded
        self.hasTradingKey = hasTradingKey
        self.hasReadOnlyToken = hasReadOnlyToken
        self.needsActivation = needsActivation
    }
}

public enum PerpsWalletAccountState {
    case unresolved
    case resolving
    case unbound
    case inactive
    case active(PerpsAccount)
}

public extension PerpsWalletAccountState {
    typealias Account = PerpsAccount
}

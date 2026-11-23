import Foundation

/// A wallet's Earn positions as the backend last answered for them. Fiat amounts are keyed by the
/// upper-case code of each currency the request named; a currency the backend had no rate for is
/// missing.
public struct EarnPortfolio: Codable, Equatable, Sendable {
    /// The multichain wallet the answer is for: a cached portfolio of another one is not this wallet's.
    public let walletId: String
    public let totalFiat: [String: Decimal]
    public let positions: [EarnPosition]

    public init(walletId: String, totalFiat: [String: Decimal], positions: [EarnPosition]) {
        self.walletId = walletId
        self.totalFiat = totalFiat
        self.positions = positions
    }
}

@frozen public enum EarnPortfolioState: Equatable, Sendable {
    /// `isStale` once a later load failed: the portfolio is the last one the backend gave.
    case loaded(EarnPortfolio, isStale: Bool)
    /// A load failed and there was nothing to fall back on.
    case unavailable
}

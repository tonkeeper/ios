import Foundation

/// One page of a wallet's per-round Tonstakers rewards, newest first.
struct TonstakersRewardsPage: Equatable, Sendable {
    struct Reward: Equatable, Sendable {
        let date: Date
        let roundId: Int?
        /// Nanotons.
        let amount: UInt64?
        /// Fraction: 0.1261 = 12.61%.
        let apy: Double?
    }

    /// Nanotons since the requested `from`, or lifetime without it; nil when the total was not requested.
    let totalReward: UInt64?
    /// Rewards in the whole requested period, not just this page.
    let totalCount: Int
    let rewards: [Reward]
}

import Foundation

/// Expected Tonstakers rewards for the rounds already started but not paid yet, newest first.
/// Rewards cover the wallet's tsTON plus its DeFi positions.
struct TonstakersUpcomingRewards: Equatable, Sendable {
    struct Round: Equatable, Sendable {
        let roundId: Int
        /// When the round is paid out.
        let cycleEnd: Date
        /// Nanotons, for the whole `balanceTston`.
        let reward: UInt64
        /// The round's growth, 0.000223 = 0.0223%: the pool's on-chain projection, or a past round's actual one.
        let roi: Double
        /// Fraction: 0.1261 = 12.61%.
        let apy: Double?
    }

    /// tsTON nano on the wallet itself.
    let walletTston: UInt64
    /// tsTON nano on the wallet plus in DeFi.
    let balanceTston: UInt64
    /// GRAM per tsTON.
    let rate: Double
    let rounds: [Round]
}

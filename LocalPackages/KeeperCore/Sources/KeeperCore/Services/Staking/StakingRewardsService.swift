import BigInt
import Foundation

@frozen public enum StakingRewardsPeriod: CaseIterable, Sendable {
    case allTime
    case month
    case halfYear
    case year

    func startDate(now: Date) -> Date? {
        let day: TimeInterval = 24 * 60 * 60
        switch self {
        case .allTime: return nil
        case .month: return now.addingTimeInterval(-30 * day)
        case .halfYear: return now.addingTimeInterval(-182 * day)
        case .year: return now.addingTimeInterval(-365 * day)
        }
    }
}

public struct StakingReward: Equatable, Hashable, Sendable {
    public let id: String
    public let date: Date
    public let amount: BigUInt
    public let apy: Decimal?
}

public struct StakingRewardsPage: Equatable, Sendable {
    public let total: BigUInt?
    public let totalCount: Int
    /// Server items in this page, including rewards dropped for a missing amount; the next page starts after them.
    public let serverItemsCount: Int
    public let items: [StakingReward]
}

public struct StakingUpcomingReward: Equatable, Sendable {
    public let amount: BigUInt
    public let roundEnd: Date
}

/// Estimated rewards on the wallet's whole tsTON (wallet plus DeFi), in nanograms.
public struct StakingCurrentRewards: Equatable, Sendable {
    public let monthly: BigUInt
    public let yearly: BigUInt
}

public struct StakingRewardsForecast: Equatable, Sendable {
    /// The wallet's reward for the pending round paid out next, or nil when it pays nothing.
    /// Only tsTON on the wallet counts, as in the rewards history; DeFi positions are left out.
    public let upcoming: StakingUpcomingReward?
    /// Nil when no round in the response pays a reward; with none pending, the latest past round's ROI is used.
    public let current: StakingCurrentRewards?
}

public protocol StakingRewardsService: Sendable {
    func loadRewards(
        address: String,
        period: StakingRewardsPeriod,
        limit: Int,
        offset: Int
    ) async throws -> StakingRewardsPage

    /// Upcoming and current rewards from one Tonstakers request. Current monthly compounds the next round's
    /// growth over 40 rounds (65 536 s each, about 30.3 days); yearly applies the pool APY (percent) once,
    /// as Tonstakers does.
    func loadRewardsForecast(address: String, apy: Decimal) async throws -> StakingRewardsForecast
}

struct StakingRewardsServiceImplementation: StakingRewardsService {
    private static let roundsPerMonth: Double = 40

    private let tonstakersAPI: TonstakersAPI

    init(tonstakersAPI: TonstakersAPI) {
        self.tonstakersAPI = tonstakersAPI
    }

    func loadRewards(
        address: String,
        period: StakingRewardsPeriod,
        limit: Int,
        offset: Int
    ) async throws -> StakingRewardsPage {
        let page = try await tonstakersAPI.rewards(
            address: address,
            from: period.startDate(now: Date()),
            limit: limit,
            offset: offset,
            includeTotal: offset == 0
        )
        let items = page.rewards.compactMap { reward -> StakingReward? in
            guard let amount = reward.amount else { return nil }
            return StakingReward(
                id: reward.roundId.map(String.init) ?? String(Int(reward.date.timeIntervalSince1970)),
                date: reward.date,
                amount: BigUInt(amount),
                apy: reward.apy.map { Decimal($0) }
            )
        }
        return StakingRewardsPage(
            total: page.totalReward.map { BigUInt($0) },
            totalCount: page.totalCount,
            serverItemsCount: page.rewards.count,
            items: items
        )
    }

    func loadRewardsForecast(address: String, apy: Decimal) async throws -> StakingRewardsForecast {
        let stake = try await tonstakersAPI.upcomingRewards(address: address)
        let nextRound = Self.nextRound(stake.rounds)
        return StakingRewardsForecast(
            upcoming: nextRound.flatMap { Self.walletReward(stake, round: $0) },
            current: nextRound.map { Self.currentRewards(stake, roundRoi: $0.roi, apy: apy) }
        )
    }

    private static func nextRound(_ rounds: [TonstakersUpcomingRewards.Round]) -> TonstakersUpcomingRewards.Round? {
        let now = Date()
        let paying = rounds.filter { $0.reward > 0 }
        return paying.filter { $0.cycleEnd > now }.min { $0.cycleEnd < $1.cycleEnd }
            ?? paying.max { $0.cycleEnd < $1.cycleEnd }
    }

    private static func walletReward(
        _ stake: TonstakersUpcomingRewards,
        round: TonstakersUpcomingRewards.Round
    ) -> StakingUpcomingReward? {
        guard stake.balanceTston > 0 else { return nil }
        let amount = BigUInt(round.reward) * BigUInt(stake.walletTston) / BigUInt(stake.balanceTston)
        guard amount > 0 else { return nil }
        return StakingUpcomingReward(amount: amount, roundEnd: round.cycleEnd)
    }

    private static func currentRewards(
        _ stake: TonstakersUpcomingRewards,
        roundRoi: Double,
        apy: Decimal
    ) -> StakingCurrentRewards {
        let amount = Double(stake.balanceTston) * stake.rate
        return StakingCurrentRewards(
            monthly: nanograms(amount * (pow(1 + roundRoi, roundsPerMonth) - 1)),
            yearly: nanograms(amount * (NSDecimalNumber(decimal: apy).doubleValue / 100))
        )
    }

    private static func nanograms(_ value: Double) -> BigUInt {
        guard value.isFinite, value > 0 else { return 0 }
        return BigUInt(value.rounded())
    }
}

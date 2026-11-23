import Foundation
import TKTonstakersAPI

/// The spec types amounts as plain integers; a negative one is a broken response, not a missing value.
struct TonstakersNegativeAmountError: Error {
    let value: Int
}

extension TonstakersRewardsPage {
    init(response: Components.Schemas.RewardsTimelineResponse) throws {
        try self.init(
            totalReward: response.total_reward_ton.map(UInt64.init(tonstakersAmount:)),
            totalCount: response.pagination.total,
            rewards: response.items.map(Reward.init(item:))
        )
    }
}

extension TonstakersRewardsPage.Reward {
    init(item: Components.Schemas.RewardsTimelineItem) throws {
        try self.init(
            date: Date(timeIntervalSince1970: TimeInterval(item.ts)),
            roundId: item.round_id,
            amount: item.reward_ton.map(UInt64.init(tonstakersAmount:)),
            apy: item.apy
        )
    }
}

extension TonstakersUpcomingRewards {
    init(response: Components.Schemas.UpcomingRewardsResponse) throws {
        try self.init(
            walletTston: UInt64(tonstakersAmount: response.wallet_tston),
            balanceTston: UInt64(tonstakersAmount: response.balance_tston),
            rate: response.rate,
            rounds: response.items.map(Round.init(item:))
        )
    }
}

extension TonstakersUpcomingRewards.Round {
    init(item: Components.Schemas.UpcomingRoundReward) throws {
        try self.init(
            roundId: item.round_id,
            cycleEnd: Date(timeIntervalSince1970: TimeInterval(item.cycle_end)),
            reward: UInt64(tonstakersAmount: item.reward_ton),
            roi: item.roi,
            apy: item.apy
        )
    }
}

private extension UInt64 {
    init(tonstakersAmount value: Int) throws {
        guard let amount = UInt64(exactly: value) else {
            throw TonstakersNegativeAmountError(value: value)
        }
        self = amount
    }
}

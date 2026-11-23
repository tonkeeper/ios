import AppUI
import BigInt
import Foundation
import KeeperCore
import TKLocalize

struct StakingRewardRowMapper {
    private let amountFormatter: AmountFormatter
    private let dateFormatter: DateFormatter
    private let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        var calendar = Calendar.current
        calendar.locale = .appLanguage
        formatter.calendar = calendar
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.hour, .minute]
        formatter.maximumUnitCount = 1
        return formatter
    }()

    init(amountFormatter: AmountFormatter, dateFormatter: DateFormatter) {
        self.amountFormatter = amountFormatter
        self.dateFormatter = dateFormatter
    }

    func map(reward: StakingReward, isSecureMode: Bool) -> StakingRewardRowState {
        let amount = isSecureMode ? .secureModeValueShort : "+" + formatAmount(reward.amount)
        let apy = reward.apy.map {
            TKLocales.StakingBalanceDetails.rewardApy(
                amountFormatter.format(decimal: $0 * 100, accessory: .none, style: .percent)
            )
        } ?? ""
        return StakingRewardRowState(
            id: reward.id,
            amount: amount,
            apy: apy,
            date: formatDate(reward.date)
        )
    }

    func formatAmount(_ amount: BigUInt) -> String {
        amountFormatter.format(
            amount: amount,
            fractionDigits: TonInfo.fractionDigits,
            accessory: .tokenSymbol(TonInfo.symbol),
            style: .compact
        )
    }

    func mapUpcoming(
        reward: StakingUpcomingReward,
        isFirstReward: Bool,
        isSecureMode: Bool,
        now: Date = Date()
    ) -> StakingUpcomingRewardSectionState {
        let remaining = reward.roundEnd.timeIntervalSince(now)
        let subtitle = remaining < 60
            ? TKLocales.StakingBalanceDetails.roundEndsSoon
            : durationFormatter.string(from: Self.roundedToDisplayedUnit(remaining))
            .map(TKLocales.StakingBalanceDetails.roundEndsIn)
            ?? TKLocales.StakingBalanceDetails.roundEndsSoon
        return StakingUpcomingRewardSectionState(
            title: isFirstReward
                ? TKLocales.StakingBalanceDetails.firstReward
                : TKLocales.StakingBalanceDetails.currentRound,
            amount: isSecureMode ? .secureModeValueShort : "\(TKLocales.Common.Numbers.approximate) " + formatAmount(reward.amount),
            subtitle: subtitle
        )
    }

    /// The formatter shows one unit and drops the rest, so round first: 1 h 59 m reads "~2 hours", not "~1 hour".
    private static func roundedToDisplayedUnit(_ interval: TimeInterval) -> TimeInterval {
        let hour: TimeInterval = 60 * 60
        let unit: TimeInterval = interval >= hour - 30 ? hour : 60
        return (interval / unit).rounded() * unit
    }

    private func formatDate(_ date: Date) -> String {
        let calendar = dateFormatter.calendar ?? .current
        dateFormatter.dateFormat = calendar.isDate(date, equalTo: Date(), toGranularity: .year)
            ? "d MMM, HH:mm"
            : "d MMM yyyy, HH:mm"
        return dateFormatter.string(from: date)
    }
}

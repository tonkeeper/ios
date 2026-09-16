import BigInt
import Foundation
import KeeperCore
import TKLocalize

struct StakingItemCommentMapper {
    struct Comment {
        let text: String
        let isCollectable: Bool
    }

    private let dateComponentsFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()

    private let amountFormatter: AmountFormatter

    init(amountFormatter: AmountFormatter) {
        self.amountFormatter = amountFormatter
    }

    func comment(
        for item: ProcessedBalanceStakingItem,
        isSecure: Bool
    ) -> Comment? {
        let estimate = formatEstimate(item: item)

        if item.info.pendingDeposit > 0 {
            let amount = formatAmount(item.info.pendingDeposit, isSecure: isSecure)
            return Comment(
                text: "\(TKLocales.BalanceList.StakingItem.Comment.staked(amount))\(estimate)",
                isCollectable: false
            )
        }

        if item.info.pendingWithdraw > 0 {
            let amount = formatAmount(item.info.pendingWithdraw, isSecure: isSecure)
            return Comment(
                text: "\(TKLocales.BalanceList.StakingItem.Comment.unstaked(amount))\(estimate)",
                isCollectable: false
            )
        }

        if item.info.readyWithdraw > 0 {
            let amount = formatAmount(item.info.readyWithdraw, isSecure: isSecure)
            return Comment(
                text: TKLocales.BalanceList.StakingItem.Comment.ready(amount),
                isCollectable: true
            )
        }

        return nil
    }

    private func formatAmount(_ amount: Int64, isSecure: Bool) -> String {
        guard !isSecure else {
            return .secureModeValueShort
        }
        return amountFormatter.format(
            amount: BigUInt(amount),
            fractionDigits: TonInfo.fractionDigits
        )
    }

    private func formatEstimate(item: ProcessedBalanceStakingItem) -> String {
        if item.poolInfo?.liquidJettonMaster == JettonMasterAddress.tonstakers {
            return " \(TKLocales.BalanceList.StakingItem.Comment.afterEndOfCycle)"
        }

        if let poolInfo = item.poolInfo,
           let formattedEstimatedTime = formatCycleEnd(timestamp: poolInfo.cycleEnd)
        {
            return "\n\(TKLocales.BalanceList.StakingItem.Comment.timeEstimate(formattedEstimatedTime))"
        }

        return ""
    }

    private func formatCycleEnd(timestamp: TimeInterval) -> String? {
        let now = Date()
        var estimateDate = Date(timeIntervalSince1970: timestamp)
        if estimateDate <= now {
            estimateDate = now
        }
        let components = Calendar.current.dateComponents(
            [.hour, .minute, .second], from: now,
            to: estimateDate
        )
        return dateComponentsFormatter.string(from: components)
    }
}

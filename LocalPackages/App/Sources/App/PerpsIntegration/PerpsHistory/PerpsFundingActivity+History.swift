import KeeperCore
import PerpsModels

extension PerpsFundingActivity {
    /// The deposit this app sent that the history lists as `activity`, while it is under way or went
    /// wrong: its steps say more than the row. A completed deposit opens its details like any other.
    func unfinishedDeposit(listedAs activity: MultichainActivity) -> PerpsDepositStatus? {
        guard activity.activityType == .perpsBalanceDeposit else { return nil }
        let hash = MultichainHistoryEventTarget.transactionHash
        let hashes = Set(activity.txIds.map(hash)).subtracting([""])
        guard !hashes.isEmpty,
              let operationId = transactions.first(where: { _, stored in
                  stored.contains { hashes.contains(hash($0)) }
              })?.key
        else { return nil }
        return deposits.first { $0.id == operationId && $0.state != .completed }
    }
}

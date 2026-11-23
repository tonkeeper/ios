import KeeperCore
import SwiftUI

/// The backend settles a Perps deposit or withdrawal row on its own schedule, and no event announces
/// it: the funds can land while the row still says pending. Details open on such a row ask for the
/// list again until the row settles, leaves the list, or the details close.
enum MultichainHistoryPendingFundingRefresh {
    /// A withdrawal to Ethereum can take more than an hour to settle, so the refresh has no total limit.
    static func delay(beforeRefresh index: Int) -> UInt64 {
        let firstDelays: [UInt64] = [5, 10, 20]
        return (index < firstDelays.count ? firstDelays[index] : 30) * 1_000_000_000
    }

    /// What the refresh follows: `nil` stops it.
    static func target(of activity: MultichainActivity?) -> MultichainHistoryActivityIdentity? {
        guard let activity, activity.status == .pending else { return nil }
        switch activity.activityType {
        case .perpsBalanceDeposit, .perpsBalanceWithdrawal:
            return MultichainHistoryActivityIdentity(activity: activity)
        default:
            return nil
        }
    }
}

extension View {
    /// `refresh` reloads the first page and returns the listed activities: a row past it is not followed.
    func refreshesWhileFundingPending(
        _ activity: MultichainActivity?,
        refresh: @escaping @MainActor () async -> [MultichainActivity]
    ) -> some View {
        task(id: MultichainHistoryPendingFundingRefresh.target(of: activity)) {
            guard let activity, MultichainHistoryPendingFundingRefresh.target(of: activity) != nil else { return }
            var index = 0
            while true {
                do {
                    try await Task.sleep(nanoseconds: MultichainHistoryPendingFundingRefresh.delay(beforeRefresh: index))
                } catch {
                    return
                }
                let listed = await refresh()
                guard MultichainHistoryEventTarget.current(of: activity, in: listed) != nil else { return }
                index += 1
            }
        }
    }
}

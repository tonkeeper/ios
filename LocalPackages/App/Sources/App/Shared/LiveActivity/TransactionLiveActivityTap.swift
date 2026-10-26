import Foundation

/// A tap on a Live Activity can open the app before `MainCoordinator` exists.
@MainActor
public enum TransactionLiveActivityTap {
    private static var pending: TransactionLiveActivityLink?
    private weak static var coordinator: MainCoordinator?

    /// - Returns: `false` for a URL that is not a Live Activity's.
    public static func handle(_ url: URL) -> Bool {
        guard let link = TransactionLiveActivityLink(url: url) else { return false }
        if let coordinator {
            coordinator.openTransactionLiveActivity(link)
        } else {
            pending = link
        }
        return true
    }

    /// The pending tap is delivered on the next main-queue turn, after the coordinator has started.
    static func attach(_ coordinator: MainCoordinator) {
        self.coordinator = coordinator
        guard let link = pending else { return }
        pending = nil
        DispatchQueue.main.async { [weak coordinator] in
            coordinator?.openTransactionLiveActivity(link)
        }
    }
}

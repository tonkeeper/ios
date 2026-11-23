import Foundation
import KeeperCore
import TKCore

/// A tap on a Live Activity can open the app before `MainCoordinator` exists.
@MainActor
public enum TransactionLiveActivityTap {
    private static var pending: (link: TransactionLiveActivityLink, click: LiveActivityClick, utm: UtmParameters)?
    private weak static var coordinator: MainCoordinator?
    private static var analyticsProvider: AnalyticsProvider?

    /// - Returns: `false` for a URL that is not a Live Activity's.
    public static func handle(_ url: URL, isColdStart: Bool) -> Bool {
        guard let link = TransactionLiveActivityLink(url: url) else { return false }
        let click = LiveActivityClick(link: link, isColdStart: isColdStart)
        let utm = UtmParameters(link: url.absoluteString)
        if let coordinator, let analyticsProvider {
            if coordinator.openTransactionLiveActivity(link) {
                analyticsProvider.log(click, utm: utm)
            }
        } else {
            pending = (link, click, utm)
        }
        return true
    }

    /// The pending tap is delivered on the next main-queue turn, after the coordinator has started.
    static func attach(_ coordinator: MainCoordinator, analyticsProvider: AnalyticsProvider) {
        self.coordinator = coordinator
        self.analyticsProvider = analyticsProvider
        guard let pending else { return }
        self.pending = nil
        DispatchQueue.main.async { [weak coordinator] in
            guard coordinator?.openTransactionLiveActivity(pending.link) == true else { return }
            analyticsProvider.log(pending.click, utm: pending.utm)
        }
    }
}

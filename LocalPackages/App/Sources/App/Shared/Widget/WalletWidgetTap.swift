import Foundation

/// A tap on a widget can open the app before `MainCoordinator` exists.
@MainActor
public enum WalletWidgetTap {
    private static var pending: (link: WalletWidgetLink, url: URL, isColdStart: Bool)?
    private weak static var coordinator: MainCoordinator?

    /// - Returns: `false` for a URL that is not a widget's.
    public static func handle(_ url: URL, isColdStart: Bool) -> Bool {
        guard let link = WalletWidgetLink(url: url) else { return false }
        if let coordinator {
            coordinator.openWalletWidget(link, url: url, isColdStart: isColdStart)
        } else {
            pending = (link, url, isColdStart)
        }
        return true
    }

    /// The pending tap is delivered on the next main-queue turn, after the coordinator has started.
    static func attach(_ coordinator: MainCoordinator) {
        self.coordinator = coordinator
        guard let pending else { return }
        self.pending = nil
        DispatchQueue.main.async { [weak coordinator] in
            coordinator?.openWalletWidget(pending.link, url: pending.url, isColdStart: pending.isColdStart)
        }
    }
}

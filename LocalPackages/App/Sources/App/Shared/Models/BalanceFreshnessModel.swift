import Foundation
import TKUIKit
import UIKit

/// Whether the amount on screen has been confirmed since the app came to the foreground, and when
/// it is worth asking for a load. It is rendered from a cache that outlives the launch, so it is
/// stale until a load answers for it, and a trip to the background makes it stale again.
@MainActor
final class BalanceFreshnessModel {
    private(set) var freshness: BalanceFreshness = .pending

    var didUpdateFreshness: ((BalanceFreshness) -> Void)?
    /// The amount is on screen and needs a load behind it: it has just appeared, or the app has
    /// come back and what it shows has not been confirmed since.
    var onNeedsRefresh: (() -> Void)?

    private var isOnScreen = false
    private var foregroundObserver: NSObjectProtocol?

    init() {
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.didEnterForeground()
            }
        }
    }

    deinit {
        foregroundObserver.map(NotificationCenter.default.removeObserver)
    }

    /// An edge, not a level: the screen re-states that a section is on it every time it reloads,
    /// and answering each of those would ask for a load that the reload is already performing.
    func didAppear() {
        guard !isOnScreen else { return }
        isOnScreen = true
        onNeedsRefresh?()
    }

    func didDisappear() {
        isOnScreen = false
    }

    func markFresh() {
        setFreshness(.actual)
    }

    private func didEnterForeground() {
        setFreshness(.pending)
        guard isOnScreen else { return }
        onNeedsRefresh?()
    }

    private func setFreshness(_ freshness: BalanceFreshness) {
        guard self.freshness != freshness else { return }
        self.freshness = freshness
        didUpdateFreshness?(freshness)
    }
}

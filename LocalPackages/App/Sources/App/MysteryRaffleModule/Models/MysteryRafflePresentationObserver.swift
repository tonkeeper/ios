import Foundation
import KeeperCore

/// Shared store subscription + `MysteryRafflePresentation` derivation for every screen
/// that shows a raffle entry point (wallet root, trade, swap). Retained by its owner —
/// `RaffleStore.addObserver` only holds a weak reference to it.
@MainActor
final class MysteryRafflePresentationObserver {
    /// `MysteryRafflePresentation`'s time-derived flags (e.g. `shouldShowMainScreenEntry`)
    /// are computed from `Date()`, so a raffle boundary (start/end/zero-fee window) can
    /// pass with no new `RaffleStore` emission — re-derive on a timer so entry points
    /// don't stay stale for the rest of the session.
    private static let refreshInterval: TimeInterval = 30

    private let onUpdate: (MysteryRafflePresentation?) -> Void

    private var raffles: [MultichainRaffle] = []
    private var refreshTimer: Timer?

    init(
        raffleStore: RaffleStore?,
        onUpdate: @escaping (MysteryRafflePresentation?) -> Void
    ) {
        self.onUpdate = onUpdate

        guard let raffleStore else { return }
        apply(raffleStore.getState())
        raffleStore.addObserver(self) { observer, event in
            guard case let .didUpdateRaffles(raffles) = event else { return }
            Task { @MainActor in
                observer.apply(raffles)
            }
        }

        refreshTimer = Timer.scheduledTimer(withTimeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.apply(self.raffles)
            }
        }
    }

    deinit {
        refreshTimer?.invalidate()
    }

    private func apply(_ raffles: [MultichainRaffle]) {
        self.raffles = raffles
        onUpdate(MysteryRafflePresentation(raffles: raffles))
    }
}

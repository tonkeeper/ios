import Foundation
import KeeperCore
import TKFeatureFlags

/// Backing state for the dev-menu Mystery Raffle screen: the QA hooks the contract exposes
/// (`_debug_now`, `pick-winners`) plus the live raffle they act on. Dev-only.
@MainActor
final class MysteryRaffleDebugViewModel: ObservableObject {
    @Published private(set) var raffle: MultichainRaffle?
    @Published private(set) var debugNow: Date?
    /// Result of the last QA call, surfaced verbatim so a gated-off endpoint (404 on prod
    /// pods) is visible instead of silently doing nothing.
    @Published private(set) var lastResult: String?
    @Published private(set) var isRunning = false

    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    private let appSettings: TKAppSettings

    init(
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        appSettings: TKAppSettings
    ) {
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.appSettings = appSettings
        debugNow = appSettings.raffleDebugNow
        raffle = MysteryRafflePresentation.selectRaffle(
            from: keeperCoreMainAssembly.storesAssembly.raffleStore.getState()
        )
    }

    var stories: [MultichainRaffleStory] {
        raffle?.stories ?? []
    }

    var walletId: String? {
        guard
            let wallet = try? keeperCoreMainAssembly.storesAssembly.walletsStore.activeWallet,
            case let .multichain(state) = wallet.multichain
        else { return nil }
        return state.walletId
    }

    // MARK: - `_debug_now`

    /// Backend resolves the active phase against this instant, so shifting it by whole weeks
    /// is what walks the raffle through its phases.
    func shiftDebugNow(byWeeks weeks: Int) {
        let base = debugNow ?? Date()
        setDebugNow(base.addingTimeInterval(Double(weeks) * 7 * 86400))
    }

    func setDebugNow(_ date: Date?) {
        appSettings.raffleDebugNow = date
        debugNow = date
        lastResult = date.map { "_debug_now = \(Self.dateFormatter.string(from: $0))" } ?? "_debug_now cleared"
        reloadRaffles()
    }

    // MARK: - `pick-winners`

    func pickWinnersRandomly() {
        forcePick(walletId: nil, prizeId: nil, description: "random pick across all wallets")
    }

    func makeCurrentWalletWin(prize: MultichainRafflePrize) {
        guard let walletId else {
            lastResult = "No multichain wallet active"
            return
        }
        forcePick(walletId: walletId, prizeId: prize.id, description: "this wallet wins \(prize.title)")
    }

    /// Empty `prize_id` clears the winner row: the wallet falls back to `lost` when it has
    /// tickets, `not_joined` otherwise.
    func clearCurrentWalletWin() {
        guard let walletId else {
            lastResult = "No multichain wallet active"
            return
        }
        forcePick(walletId: walletId, prizeId: nil, description: "cleared winner row for this wallet")
    }

    func reloadRaffles() {
        guard let walletId else { return }
        keeperCoreMainAssembly.loadersAssembly.raffleLoader.loadRaffles(
            walletId: walletId,
            lang: Locale.current.languageCode ?? "en",
            ids: nil
        )
        refreshRaffleAfterReload()
    }

    private func forcePick(walletId: String?, prizeId: String?, description: String) {
        guard let raffleId = raffle?.id else {
            lastResult = "No raffle loaded"
            return
        }
        isRunning = true
        let service = keeperCoreMainAssembly.servicesAssembly.multichainService()
        Task { @MainActor [weak self] in
            do {
                try await service.forcePickRaffleWinners(
                    raffleId: raffleId,
                    walletId: walletId,
                    prizeId: prizeId
                )
                self?.lastResult = "Picked: \(description)"
                self?.reloadRaffles()
            } catch {
                self?.lastResult = "Failed: \(error)"
            }
            self?.isRunning = false
        }
    }

    /// `RaffleLoader` feeds the store asynchronously; re-read it shortly after so the screen
    /// shows the post-pick state without an observer for a dev-only surface.
    private func refreshRaffleAfterReload() {
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1 * NSEC_PER_SEC)
            guard let self else { return }
            raffle = MysteryRafflePresentation.selectRaffle(
                from: keeperCoreMainAssembly.storesAssembly.raffleStore.getState()
            )
        }
    }

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy HH:mm"
        return formatter
    }()
}

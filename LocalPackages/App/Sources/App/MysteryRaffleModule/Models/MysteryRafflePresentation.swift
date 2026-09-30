import Foundation
import KeeperCore
import TKLocalize

struct MysteryRafflePresentation: Equatable {
    let raffle: MultichainRaffle
    private let dismissStore: MysteryRaffleTradeBannerDismissStore
    private let walletsListDismissStore: MysteryRaffleWalletsListBannerDismissStore

    init?(
        raffles: [MultichainRaffle],
        dismissStore: MysteryRaffleTradeBannerDismissStore = UserDefaultsMysteryRaffleTradeBannerDismissStore(),
        walletsListDismissStore: MysteryRaffleWalletsListBannerDismissStore = UserDefaultsMysteryRaffleWalletsListBannerDismissStore()
    ) {
        guard let raffle = Self.selectRaffle(from: raffles) else {
            return nil
        }
        self.raffle = raffle
        self.dismissStore = dismissStore
        self.walletsListDismissStore = walletsListDismissStore
    }

    var shouldShowMainScreenEntry: Bool {
        let now = RaffleClock.now
        return !raffle.isMigrationPhase && raffle.startsAt < now && now < raffle.endsAt
    }

    var shouldShowTradeBanner: Bool {
        raffle.banner != nil && RaffleClock.now < raffle.endsAt && !dismissStore.isDismissed(raffleId: raffle.id)
    }

    func tradeBannerDismissed() {
        dismissStore.setDismissed(raffleId: raffle.id)
    }

    var shouldShowWalletsListBanner: Bool {
        raffle.banner != nil && RaffleClock.now < raffle.endsAt && !walletsListDismissStore.isDismissed(raffleId: raffle.id)
    }

    func walletsListBannerDismissed() {
        walletsListDismissStore.setDismissed(raffleId: raffle.id)
    }

    var shouldShowSwapPromo: Bool {
        guard let zeroFeeEndsAt = raffle.progress?.zeroFeeEndsAt else { return false }
        return RaffleClock.now < zeroFeeEndsAt
    }

    var compactTitle: String {
        hasTickets ? raffle.compactBanner.activeTitle : raffle.compactBanner.defaultTitle
    }

    var ticketsText: String? {
        let tickets = raffle.progress?.ticketsTotal ?? 0
        guard tickets > 0 else { return nil }
        return tickets == 1 ? TKLocales.MysteryRaffle.Tickets.Count.one : TKLocales.MysteryRaffle.Tickets.Count.other(tickets)
    }

    private var hasTickets: Bool {
        (raffle.progress?.ticketsTotal ?? 0) > 0
    }

    static func selectRaffle(from raffles: [MultichainRaffle]) -> MultichainRaffle? {
        raffles.first { $0.status != .won && $0.status != .lost }
            ?? raffles.first
    }

    static func == (lhs: MysteryRafflePresentation, rhs: MysteryRafflePresentation) -> Bool {
        lhs.raffle == rhs.raffle
            && lhs.shouldShowMainScreenEntry == rhs.shouldShowMainScreenEntry
            && lhs.shouldShowSwapPromo == rhs.shouldShowSwapPromo
    }
}

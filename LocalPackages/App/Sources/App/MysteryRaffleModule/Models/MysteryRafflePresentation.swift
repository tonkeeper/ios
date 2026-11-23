import Foundation
import KeeperCore
import TKLocalize

struct MysteryRafflePresentation: Equatable {
    let raffle: MultichainRaffle
    let shouldShowWalletEntry: Bool
    let shouldShowTradeEntry: Bool
    let shouldShowSwapPromo: Bool
    private let dismissStore: MysteryRaffleTradeBannerDismissStore
    private let walletsListDismissStore: MysteryRaffleWalletsListBannerDismissStore

    init?(
        raffles: [MultichainRaffle],
        dismissStore: MysteryRaffleTradeBannerDismissStore = UserDefaultsMysteryRaffleTradeBannerDismissStore(),
        walletsListDismissStore: MysteryRaffleWalletsListBannerDismissStore = UserDefaultsMysteryRaffleWalletsListBannerDismissStore(),
        now: Date = Date()
    ) {
        guard let raffle = Self.selectRaffle(from: raffles) else {
            return nil
        }
        self.init(raffle: raffle, dismissStore: dismissStore, walletsListDismissStore: walletsListDismissStore, now: now)
    }

    init(
        raffle: MultichainRaffle,
        dismissStore: MysteryRaffleTradeBannerDismissStore = UserDefaultsMysteryRaffleTradeBannerDismissStore(),
        walletsListDismissStore: MysteryRaffleWalletsListBannerDismissStore = UserDefaultsMysteryRaffleWalletsListBannerDismissStore(),
        now: Date = Date()
    ) {
        self.raffle = raffle
        let hasStarted = raffle.startsAt < now
        self.shouldShowWalletEntry = hasStarted && !raffle.isMigrationPhase && raffle.leaderboard == nil
        self.shouldShowTradeEntry = hasStarted && now < raffle.endsAt && raffle.leaderboard != nil
        self.shouldShowSwapPromo = raffle.progress?.zeroFeeEndsAt.map { now < $0 } ?? false
        self.dismissStore = dismissStore
        self.walletsListDismissStore = walletsListDismissStore
    }

    var shouldShowTradeBanner: Bool {
        raffle.banner != nil && !dismissStore.isDismissed(raffleId: raffle.id)
    }

    func tradeBannerDismissed() {
        dismissStore.setDismissed(raffleId: raffle.id)
    }

    var shouldShowWalletsListBanner: Bool {
        raffle.banner != nil && !walletsListDismissStore.isDismissed(raffleId: raffle.id)
    }

    func walletsListBannerDismissed() {
        walletsListDismissStore.setDismissed(raffleId: raffle.id)
    }

    var compactTitle: String {
        badgeText == nil ? raffle.compactBanner.defaultTitle : raffle.compactBanner.activeTitle
    }

    var compactSymbol: RaffleSymbol {
        RaffleSymbol(iconId: raffle.compactBanner.iconId) ?? .ticket
    }

    var badgeText: String? {
        if let points = raffle.leaderboard?.points {
            guard points > 0 else { return nil }
            return points == 1
                ? TKLocales.MysteryRaffle.Points.Count.one
                : TKLocales.MysteryRaffle.Points.Count.other(Self.pointsFormatter.format(decimal: points))
        }
        let tickets = raffle.progress?.ticketsTotal ?? 0
        guard tickets > 0 else { return nil }
        return tickets == 1 ? TKLocales.MysteryRaffle.Tickets.Count.one : TKLocales.MysteryRaffle.Tickets.Count.other(tickets)
    }

    static func all(from raffles: [MultichainRaffle], now: Date = Date()) -> [MysteryRafflePresentation] {
        raffles.map { MysteryRafflePresentation(raffle: $0, now: now) }
    }

    static func selectRaffle(from raffles: [MultichainRaffle]) -> MultichainRaffle? {
        raffles.first { $0.status != .won && $0.status != .lost }
            ?? raffles.first
    }

    private static let pointsFormatter = AmountFormatter()

    static func == (lhs: MysteryRafflePresentation, rhs: MysteryRafflePresentation) -> Bool {
        lhs.raffle == rhs.raffle
            && lhs.shouldShowWalletEntry == rhs.shouldShowWalletEntry
            && lhs.shouldShowTradeEntry == rhs.shouldShowTradeEntry
            && lhs.shouldShowSwapPromo == rhs.shouldShowSwapPromo
    }
}

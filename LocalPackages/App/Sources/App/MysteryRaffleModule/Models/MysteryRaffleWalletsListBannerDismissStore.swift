import Foundation

protocol MysteryRaffleWalletsListBannerDismissStore: AnyObject {
    func isDismissed(raffleId: String) -> Bool
    func setDismissed(raffleId: String)
}

final class UserDefaultsMysteryRaffleWalletsListBannerDismissStore: MysteryRaffleWalletsListBannerDismissStore {
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func isDismissed(raffleId: String) -> Bool {
        userDefaults.bool(forKey: key(raffleId: raffleId))
    }

    func setDismissed(raffleId: String) {
        userDefaults.set(true, forKey: key(raffleId: raffleId))
    }

    private func key(raffleId: String) -> String {
        "mysteryRaffle.walletsListBannerDismissed.\(raffleId)"
    }
}

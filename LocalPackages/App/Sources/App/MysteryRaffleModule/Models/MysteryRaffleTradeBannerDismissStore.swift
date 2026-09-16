import Foundation

protocol MysteryRaffleTradeBannerDismissStore: AnyObject {
    func isDismissed(raffleId: String) -> Bool
    func setDismissed(raffleId: String)
    func resetDismissedBanners()
}

final class UserDefaultsMysteryRaffleTradeBannerDismissStore: MysteryRaffleTradeBannerDismissStore {
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

    func resetDismissedBanners() {
        userDefaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(Self.keyPrefix) }
            .forEach(userDefaults.removeObject(forKey:))
    }

    private func key(raffleId: String) -> String {
        "\(Self.keyPrefix)\(raffleId)"
    }

    private static let keyPrefix = "mysteryRaffle.tradeBannerDismissed."
}

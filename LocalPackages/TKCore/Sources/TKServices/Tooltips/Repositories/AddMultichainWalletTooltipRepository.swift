import Foundation

public final class AddMultichainWalletTooltipRepository {
    public enum Placement: String {
        case main
        case walletsList = "wallets_list"
    }

    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public var shownCount: Int {
        get {
            userDefaults.integer(forKey: .addMultichainWalletTooltipShownCountKey)
        }
        set {
            userDefaults.set(newValue, forKey: .addMultichainWalletTooltipShownCountKey)
        }
    }

    public var lastShownDate: Date? {
        get {
            userDefaults.object(forKey: .addMultichainWalletTooltipLastShownDateKey) as? Date
        }
        set {
            userDefaults.set(newValue, forKey: .addMultichainWalletTooltipLastShownDateKey)
        }
    }

    public func lastShownDate(for placement: Placement) -> Date? {
        userDefaults.object(forKey: placementDayKey(placement)) as? Date
    }

    public func setLastShownDate(_ date: Date, for placement: Placement) {
        userDefaults.set(date, forKey: placementDayKey(placement))
    }

    public func resetPersistentState() {
        userDefaults.removeObject(forKey: .addMultichainWalletTooltipShownCountKey)
        userDefaults.removeObject(forKey: .addMultichainWalletTooltipLastShownDateKey)
        for placement in Placement.allCases {
            userDefaults.removeObject(forKey: placementDayKey(placement))
        }
    }

    private func placementDayKey(_ placement: Placement) -> String {
        "\(String.addMultichainWalletTooltipPlacementDayKeyPrefix)\(placement.rawValue)"
    }
}

extension AddMultichainWalletTooltipRepository.Placement: CaseIterable {}

private extension String {
    static let addMultichainWalletTooltipShownCountKey = "add_multichain_wallet_tooltip_shown_count"
    static let addMultichainWalletTooltipLastShownDateKey = "add_multichain_wallet_tooltip_last_shown_date"
    static let addMultichainWalletTooltipPlacementDayKeyPrefix = "add_multichain_wallet_tooltip_day_"
}

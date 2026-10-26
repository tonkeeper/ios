import Foundation

public final class FavoriteTooltipRepository {
    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public var hasBeenShown: Bool {
        get {
            userDefaults.bool(forKey: .favoriteTooltipShownKey)
        }
        set {
            userDefaults.set(newValue, forKey: .favoriteTooltipShownKey)
        }
    }

    public func resetPersistentState() {
        userDefaults.removeObject(forKey: .favoriteTooltipShownKey)
    }
}

private extension String {
    static let favoriteTooltipShownKey = "favorite_tooltip_shown"
}

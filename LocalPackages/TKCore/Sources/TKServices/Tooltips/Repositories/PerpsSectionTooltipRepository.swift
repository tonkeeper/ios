import Foundation

public final class PerpsSectionTooltipRepository {
    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public var hasBeenShown: Bool {
        get {
            userDefaults.bool(forKey: .perpsSectionTooltipShownKey)
        }
        set {
            userDefaults.set(newValue, forKey: .perpsSectionTooltipShownKey)
        }
    }

    public func resetPersistentState() {
        userDefaults.removeObject(forKey: .perpsSectionTooltipShownKey)
    }
}

private extension String {
    static let perpsSectionTooltipShownKey = "perps_section_tooltip_shown"
}

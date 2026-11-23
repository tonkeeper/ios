import Foundation

public final class EarnSectionTooltipRepository {
    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public var shownCount: Int {
        get {
            userDefaults.integer(forKey: .earnSectionTooltipShownCountKey)
        }
        set {
            userDefaults.set(newValue, forKey: .earnSectionTooltipShownCountKey)
        }
    }

    public var lastShownDate: Date? {
        get {
            userDefaults.object(forKey: .earnSectionTooltipLastShownDateKey) as? Date
        }
        set {
            userDefaults.set(newValue, forKey: .earnSectionTooltipLastShownDateKey)
        }
    }

    public func resetPersistentState() {
        userDefaults.removeObject(forKey: .earnSectionTooltipShownCountKey)
        userDefaults.removeObject(forKey: .earnSectionTooltipLastShownDateKey)
    }
}

private extension String {
    static let earnSectionTooltipShownCountKey = "earn_section_tooltip_shown_count"
    static let earnSectionTooltipLastShownDateKey = "earn_section_tooltip_last_shown_date"
}

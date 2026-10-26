import Foundation

public final class NewHistoryEntryPointTooltipRepository {
    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public var shownCount: Int {
        get {
            userDefaults.integer(forKey: .newHistoryEntryPointTooltipShownCountKey)
        }
        set {
            userDefaults.set(newValue, forKey: .newHistoryEntryPointTooltipShownCountKey)
        }
    }

    public var isTargetActionPerformed: Bool {
        get {
            userDefaults.bool(forKey: .newHistoryEntryPointTooltipTargetActionPerformedKey)
        }
        set {
            userDefaults.set(newValue, forKey: .newHistoryEntryPointTooltipTargetActionPerformedKey)
        }
    }

    public func resetPersistentState() {
        userDefaults.removeObject(forKey: .newHistoryEntryPointTooltipShownCountKey)
        userDefaults.removeObject(forKey: .newHistoryEntryPointTooltipTargetActionPerformedKey)
    }
}

private extension String {
    static let newHistoryEntryPointTooltipShownCountKey = "new_history_entry_point_tooltip_shown_count"
    static let newHistoryEntryPointTooltipTargetActionPerformedKey = "new_history_entry_point_tooltip_understood"
}

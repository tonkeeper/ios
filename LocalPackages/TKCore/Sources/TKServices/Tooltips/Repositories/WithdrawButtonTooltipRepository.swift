import Foundation

public final class WithdrawButtonTooltipRepository {
    private let userDefaults: UserDefaults
    private let tooltipData: TooltipDataRepository

    public init(
        tooltipData: TooltipDataRepository,
        userDefaults: UserDefaults = .standard
    ) {
        self.userDefaults = userDefaults
        self.tooltipData = tooltipData
    }

    public var shownCount: Int {
        get {
            userDefaults.integer(forKey: .withdrawButtonTooltipShownCountKey)
        }
        set {
            userDefaults.set(newValue, forKey: .withdrawButtonTooltipShownCountKey)
        }
    }

    public var isTargetActionPerformed: Bool {
        get {
            userDefaults.bool(forKey: .withdrawButtonTooltipTargetActionPerformedKey)
        }
        set {
            userDefaults.set(newValue, forKey: .withdrawButtonTooltipTargetActionPerformedKey)
        }
    }

    public func resetPersistentState() {
        userDefaults.removeObject(forKey: .withdrawButtonTooltipShownCountKey)
        userDefaults.removeObject(forKey: .withdrawButtonTooltipTargetActionPerformedKey)
    }
}

private extension String {
    static let withdrawButtonTooltipShownCountKey = "withdraw_button_tooltip_shown_count"
    static let withdrawButtonTooltipTargetActionPerformedKey = "withdraw_button_tooltip_understood"
}

import Foundation

final class WithdrawButtonTooltipRepository {
    private let userDefaults: UserDefaults
    private let tooltipData: TooltipDataRepository

    init(
        tooltipData: TooltipDataRepository,
        userDefaults: UserDefaults = .standard
    ) {
        self.userDefaults = userDefaults
        self.tooltipData = tooltipData
    }

    var shownCount: Int {
        get {
            userDefaults.integer(forKey: .withdrawButtonTooltipShownCountKey)
        }
        set {
            userDefaults.set(newValue, forKey: .withdrawButtonTooltipShownCountKey)
        }
    }

    var isInstructionUnderstood: Bool {
        get {
            userDefaults.bool(forKey: .withdrawButtonTooltipUnderstoodKey)
        }
        set {
            userDefaults.set(newValue, forKey: .withdrawButtonTooltipUnderstoodKey)
        }
    }

    func resetPersistentState() {
        userDefaults.removeObject(forKey: .withdrawButtonTooltipShownCountKey)
        userDefaults.removeObject(forKey: .withdrawButtonTooltipUnderstoodKey)
    }
}

private extension String {
    static let withdrawButtonTooltipShownCountKey = "withdraw_button_tooltip_shown_count"
    static let withdrawButtonTooltipUnderstoodKey = "withdraw_button_tooltip_understood"
}

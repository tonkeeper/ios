import Foundation

public final class TradeTabTooltipRepository {
    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public var isTargetActionPerformed: Bool {
        get {
            userDefaults.bool(forKey: .tradeTabTooltipTargetActionPerformedKey)
        }
        set {
            userDefaults.set(newValue, forKey: .tradeTabTooltipTargetActionPerformedKey)
        }
    }

    public var shownCount: Int {
        get {
            userDefaults.integer(forKey: .tradeTabButtonTooltipShownCountKey)
        }
        set {
            userDefaults.set(newValue, forKey: .tradeTabButtonTooltipShownCountKey)
        }
    }

    public func resetPersistentState() {
        userDefaults.removeObject(forKey: .tradeTabTooltipTargetActionPerformedKey)
        userDefaults.removeObject(forKey: .tradeTabButtonTooltipShownCountKey)
    }
}

private extension String {
    static let tradeTabTooltipTargetActionPerformedKey = "trade_tab_tooltip_understood"
    static let tradeTabButtonTooltipShownCountKey = "trade_tab__tooltip_shown_count"
}

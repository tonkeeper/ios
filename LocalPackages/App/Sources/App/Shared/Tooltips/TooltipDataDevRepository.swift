import Foundation

private extension String {
    static var devTooltipFirstLaunchDateKey = "dev_tooltip_first_launch_date"
}

final class TooltipDataOverridesRepository {
    private let userDefaults: UserDefaults
    private let appStoreEnvironment: Bool

    init(
        userDefaults: UserDefaults = .standard,
        appStoreEnvironment: Bool
    ) {
        self.userDefaults = userDefaults
        self.appStoreEnvironment = appStoreEnvironment
    }
}

extension TooltipDataOverridesRepository {
    var firstLaunchDate: Date? {
        get {
            if appStoreEnvironment {
                return nil
            }
            guard let timeInterval = userDefaults.value(forKey: .devTooltipFirstLaunchDateKey) as? TimeInterval else {
                return nil
            }
            return Date(timeIntervalSince1970: timeInterval)
        }
        set {
            if appStoreEnvironment {
                return
            }
            userDefaults.set(newValue?.timeIntervalSince1970, forKey: .devTooltipFirstLaunchDateKey)
        }
    }
}

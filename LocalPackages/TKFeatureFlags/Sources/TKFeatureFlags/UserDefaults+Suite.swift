import Foundation

extension UserDefaults {
    static var tkFeatureFlagsDefaults: UserDefaults {
        UserDefaults(
            suiteName: "featureFlags.tkFeatureFlags.tonkeeper"
        ) ?? .standard
    }
}

import Foundation

public enum TKFeatureFlags {
    public static let localProvider: TKLocalFeatureFlagsProvider = UserDefaultsLocalFeatureFlagsProvider()
}

public final class DummyFeatureFlags: TKFeatureFlags {
    public init() {}

    public subscript(flag: FeatureFlag) -> Bool {
        get {
            flag.defaultValue
        }
        set {}
    }

    public func resetValue(for flag: FeatureFlag) {}

    public func loadRemoteConfig() async {}

    public var allValues: [FeatureFlag: FeatureFlagValue] {
        [:]
    }
}

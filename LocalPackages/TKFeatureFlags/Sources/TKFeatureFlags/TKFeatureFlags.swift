import UIKit

public protocol TKFeatureFlags: AnyObject {
    subscript(flag: FeatureFlag) -> Bool { get set }
    /// Value forced from a dev-only channel, `nil` when the flag falls through to remote or default.
    func devOverride(for flag: FeatureFlag) -> Bool?
    func resetValue(for flag: FeatureFlag)
    func loadRemoteConfig() async

    var allValues: [FeatureFlag: FeatureFlagValue] { get }
}

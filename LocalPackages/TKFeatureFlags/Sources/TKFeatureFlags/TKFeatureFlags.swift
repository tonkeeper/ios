import UIKit

public protocol TKFeatureFlags: AnyObject {
    subscript(flag: FeatureFlag) -> Bool { get set }
    func resetValue(for flag: FeatureFlag)
    func loadRemoteConfig() async

    var allValues: [FeatureFlag: FeatureFlagValue] { get }
}

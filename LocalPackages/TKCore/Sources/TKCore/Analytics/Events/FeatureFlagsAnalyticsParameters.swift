import Foundation
import TKFeatureFlags

public extension [FeatureFlag: Bool] {
    /// Off-schema `ff_<remote key>` fields for the enabled flags, matching the Android payload.
    var analyticsParameters: [String: String] {
        reduce(into: [String: String]()) { result, entry in
            guard entry.value, let remoteKey = entry.key.remoteKey else { return }
            result["ff_\(remoteKey)"] = "true"
        }
    }
}

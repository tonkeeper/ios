internal import TKAppInfo
import Foundation
import TKLogging
import UIKit

public struct StaticFlagOverrides: Codable, Equatable {
    public let featureFlags: [String: Bool]?
    public let bootConfigurationFlags: [String: Bool]?
}

public extension StaticFlagOverrides {
    static let bundleResourceName = "FlagsOverride"

    static let shared: StaticFlagOverrides? = loadFromBundle(.main)

    static func loadFromBundle(_ bundle: Bundle) -> StaticFlagOverrides? {
        guard !UIApplication.shared.isAppStoreEnvironment else {
            return nil
        }
        guard let url = bundle.url(forResource: bundleResourceName, withExtension: "json") else {
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(StaticFlagOverrides.self, from: data)
            let featureCount = decoded.featureFlags?.count ?? 0
            let bootCount = decoded.bootConfigurationFlags?.count ?? 0
            guard featureCount + bootCount > 0 else {
                return nil
            }
            Log.i("StaticFlagOverrides loaded: \(featureCount) featureFlags, \(bootCount) bootConfigurationFlags")
            return decoded
        } catch {
            Log.w("StaticFlagOverrides: failed to decode \(url.lastPathComponent): \(error)")
            return nil
        }
    }
}

import Foundation
import KeeperCore
import TKFeatureFlags
import UIKit

public struct AppInfoProvider: KeeperCore.AppInfoProvider {
    private let userDefaults: UserDefaults
    private let storefrontCountryCodeCache: StorefrontCountryCodeCache

    init(
        userDefaults: UserDefaults,
        storefrontCountryCodeCache: StorefrontCountryCodeCache
    ) {
        self.userDefaults = userDefaults
        self.storefrontCountryCodeCache = storefrontCountryCodeCache
    }

    public var version: String {
        overridenVersion ?? InfoProvider.appVersion()
    }

    public var userAgent: String {
        let productName = InfoProvider.appName()
            .split(whereSeparator: \.isWhitespace)
            .joined()
        return "\(productName)/\(version) (\(operatingSystemName); \(operatingSystemVersion); \(deviceName))"
    }

    public var platform: String {
        InfoProvider.platform()
    }

    public var language: String {
        let languageCodeIdentifier: String? = {
            if #available(iOS 16, *) {
                return Locale(identifier: Locale.preferredLanguages[0]).language.languageCode?.identifier
            } else {
                return Locale(identifier: Locale.preferredLanguages[0]).languageCode
            }
        }()

        guard let languageCodeIdentifier else {
            return "en"
        }
        return languageCodeIdentifier
    }

    public var deviceModel: String {
        #if targetEnvironment(simulator)
            if let simulatorModel = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
                return simulatorModel
            }
        #endif
        var systemInfo = utsname()
        uname(&systemInfo)

        let machineMirror = Mirror(reflecting: systemInfo.machine)
        return machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
    }

    public var storeCountryCode: String? {
        get async {
            if let overridenStoreCountryCode {
                return overridenStoreCountryCode
            }

            return await storefrontCountryCodeCache.countryCode()
        }
    }

    var cachedStoreCountryCode: String? {
        if let overridenStoreCountryCode {
            return overridenStoreCountryCode
        }

        return storefrontCountryCodeCache.cachedCountryCode
    }

    public var deviceCountryCode: String? {
        if let overridenDeviceCountryCode {
            return overridenDeviceCountryCode
        }

        return Locale.current.regionCode
    }

    public var isVPNActive: Bool {
        VPNStatus.isVPNConnected()
    }

    public var timeZoneIdentifier: String {
        TimeZone.current.identifier
    }

    public func overrideDeviceCountryCode(_ countryCode: String?) {
        userDefaults.set(countryCode, forKey: .overridenDeviceCountryCodeKey)
    }

    public func overrideStoreCountryCode(_ countryCode: String?) {
        userDefaults.set(countryCode, forKey: .overridenStoreCountryCodeKey)
    }

    public func overrideVersion(_ version: String?) {
        userDefaults.set(version, forKey: .overridenVersionKey)
    }

    public var overridenDeviceCountryCode: String? {
        userDefaults.string(forKey: .overridenDeviceCountryCodeKey)
    }

    public var overridenStoreCountryCode: String? {
        userDefaults.string(forKey: .overridenStoreCountryCodeKey)
    }

    public var overridenVersion: String? {
        userDefaults.string(forKey: .overridenVersionKey)
    }

    private var operatingSystemName: String {
        UIDevice.current.systemName
    }

    private var operatingSystemVersion: String {
        UIDevice.current.systemVersion
    }

    private var deviceName: String {
        UIDevice.current.model
    }
}

private extension String {
    static let overridenDeviceCountryCodeKey = "tkcore_overridenDeviceCountryCode"
    static let overridenStoreCountryCodeKey = "tkcore_overridenStoreCountryCode"
    static let overridenVersionKey = "tkcore_overridenVersion"
}

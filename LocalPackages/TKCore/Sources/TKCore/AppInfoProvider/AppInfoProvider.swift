import Foundation
import KeeperCore
import StoreKit
import UIKit

public struct AppInfoProvider: KeeperCore.AppInfoProvider {
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }

    public var version: String {
        InfoProvider.appVersion()
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

    public var storeCountryCode: String? {
        get async {
            if let overridenStoreCountryCode {
                return overridenStoreCountryCode
            }

            let countryCodeAlpha3 = await Storefront.current?.countryCode

            guard let countryCodeAlpha3 else {
                return nil
            }
            return Locale.current.alpha2Code(from: countryCodeAlpha3)
        }
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

    public var overridenDeviceCountryCode: String? {
        userDefaults.string(forKey: .overridenDeviceCountryCodeKey)
    }

    public var overridenStoreCountryCode: String? {
        userDefaults.string(forKey: .overridenStoreCountryCodeKey)
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

private extension Locale {
    private static var availableRegions: [Locale] = Locale.availableIdentifiers.map { Locale(identifier: $0) }

    init?(isoCode: String, from: Locale = .autoupdatingCurrent) {
        guard let locale = from.locale(isoCode: isoCode) else { return nil }
        self = locale
    }

    func alpha2Code(from isoCode: String) -> String? {
        let regionName = localizedString(forRegionCode: isoCode) ?? ""
        return Self.availableRegions.first(where: { localizedString(forRegionCode: $0.regionCode ?? "") == regionName })?.regionCode
    }

    func locale(isoCode: String) -> Locale? {
        let alpha2Code = alpha2Code(from: isoCode)
        var matchingLocale: Locale?

        for region in Self.availableRegions {
            if region.regionCode == alpha2Code {
                if region.languageCode == languageCode {
                    return region
                } else if matchingLocale == nil {
                    matchingLocale = region
                }
            }
        }

        return matchingLocale
    }
}

private extension String {
    static let overridenDeviceCountryCodeKey = "tkcore_overridenDeviceCountryCode"
    static let overridenStoreCountryCodeKey = "tkcore_overridenStoreCountryCode"
}

import Foundation
import KeeperCore
import StoreKit

public struct AppInfoProvider: KeeperCore.AppInfoProvider {
  public var version: String {
    InfoProvider.appVersion()
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
    let countryCodeAlpha3 = SKPaymentQueue.default().storefront?.countryCode
    
    guard let countryCodeAlpha3 else {
      return nil
    }
    
    return Locale.current.alpha2Code(from: countryCodeAlpha3)
  }
  
  public var deviceCountryCode: String? {
    return Locale.current.regionCode
  }
}

private extension Locale {
  
  private static var availableRegions: [Locale] = { Locale.availableIdentifiers.map { Locale(identifier: $0) } }()
  
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

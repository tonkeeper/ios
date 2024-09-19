import Foundation
import KeeperCore

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
}

//
//  CoreAssembly.swift
//  
//
//  Created by Grigory on 29.9.23..
//

import UIKit

public struct CoreAssembly {
  
  public let appStateTracker = AppStateTracker()
  public let reachabilityTracker = ReachabilityTracker()
  public let featureFlagsProvider: FeatureFlagsProvider
  
  public init(featureFlagsProvider: FeatureFlagsProvider = FeatureFlagsProvider()) {
    self.featureFlagsProvider = featureFlagsProvider
  }
  
  public var cacheURL: URL {
    documentsURL
  }
    
  public var sharedCacheURL: URL {
    if let appGroupId: String = InfoProvider.appGroupName(),
       let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) {
      return containerURL
    } else {
      return documentsURL
    }
  }

  public var documentsURL: URL {
    let documentsDirectory: URL
    if #available(iOS 16.0, *) {
      documentsDirectory = URL.documentsDirectory
    } else {
      documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    return documentsDirectory
  }
  
  public var keychainAccessGroupIdentifier: String {
    guard let keychainAccessGroup: String = InfoProvider.keychainAccessGroup(),
          let appIdentifierPrefix: String = InfoProvider.appIdentifierPrefix() else {
      return ""
    }
    return appIdentifierPrefix+keychainAccessGroup
  }
  
  public var fileManager: FileManager {
    .default
  }
  
  public func urlOpener() -> URLOpener {
    UIApplication.shared
  }
  
  public func appStoreReviewer() -> AppStoreReviewer {
    UIApplication.shared
  }
  
  public var appSettings: AppSettings {
    AppSettings(userDefaults: UserDefaults(suiteName: .appSettingsSuiteName) ?? .standard)
  }
  
  public var formattersAssembly: FormattersAssembly {
    FormattersAssembly()
  }
}

private extension String {
  static let appSettingsSuiteName = "app_settings"
}

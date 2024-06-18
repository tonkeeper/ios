//
//  InfoProvider.swift
//
//
//  Created by Grigory on 29.9.23..
//

import Foundation

struct InfoProvider {
  enum Keys: String {
    case appVersion = "CFBundleShortVersionString"
    case buildVersion = "CFBundleVersion"
    case appGroupName = "APP_GROUP_IDENTIFIER"
    case appName = "APP_NAME"
    case keychainAccessGroup = "KEYCHAIN_ACCESS_GROUP"
    case appIdentifierPrefix = "AppIdentifierPrefix"

  }
  
  static func value<T>(key: Keys) -> T? {
    Bundle.main.object(forInfoDictionaryKey: key.rawValue) as? T
  }
  
  static func appVersion() -> String? {
    self.value(key: .appVersion)
  }
  
  static func buildVersion() -> String? {
    self.value(key: .buildVersion)
  }
  
  static func appGroupName() -> String? {
    self.value(key: .appGroupName)
  }
  
  static func appName() -> String? {
    self.value(key: .appName)
  }
  
  static func keychainAccessGroup() -> String? {
    self.value(key: .keychainAccessGroup)
  }
  
  static func appIdentifierPrefix() -> String? {
    self.value(key: .appIdentifierPrefix)
  }
}

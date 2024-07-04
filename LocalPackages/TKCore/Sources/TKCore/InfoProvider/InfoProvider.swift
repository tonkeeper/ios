//
//  InfoProvider.swift
//
//
//  Created by Grigory on 29.9.23..
//

import Foundation

public struct InfoProvider {
  enum Keys: String {
    case appVersion = "CFBundleShortVersionString"
    case buildVersion = "CFBundleVersion"
    case appGroupName = "APP_GROUP_IDENTIFIER"
    case appName = "APP_NAME"
    case keychainAccessGroup = "KEYCHAIN_ACCESS_GROUP"
    case appIdentifierPrefix = "AppIdentifierPrefix"
    case aptabaseKey = "APTABASE_KEY"
    case aptabaseEndpoint = "APTABASE_ENDPOINT"
  }
  
  static func value<T>(key: Keys) -> T? {
    Bundle.main.object(forInfoDictionaryKey: key.rawValue) as? T
  }
  
  public static func appVersion() -> String? {
    self.value(key: .appVersion)
  }
  
  public static func aptabaseKey() -> String? {
    self.value(key: .aptabaseKey)
  }
  
  public static func aptabaseEndpoint() -> String? {
    self.value(key: .aptabaseEndpoint)
  }
  
  public static func buildVersion() -> String? {
    self.value(key: .buildVersion)
  }
  
  public static func appGroupName() -> String? {
    self.value(key: .appGroupName)
  }
  
  public static func appName() -> String {
    self.value(key: .appName) ?? .defaultAppName
  }
  
  public static func keychainAccessGroup() -> String? {
    self.value(key: .keychainAccessGroup)
  }
  
  public static func appIdentifierPrefix() -> String? {
    self.value(key: .appIdentifierPrefix)
  }
}

private extension String {
  static let defaultAppName = "Tonkeeper"
}

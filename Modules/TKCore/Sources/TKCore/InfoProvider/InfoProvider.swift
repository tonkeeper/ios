//
//  InfoProvider.swift
//
//
//  Created by Grigory on 29.9.23..
//

import Foundation

public enum InfoProviderError: Swift.Error {
  case failedToGetValue(key: String)
}

public enum InfoKey: String {
  case appGroupName = "APP_GROUP_IDENTIFIER"
  case appName = "APP_NAME"
  case appVersion = "CFBundleShortVersionString"
  case buildVersion = "CFBundleVersion"
  case keychainAccessGroup = "KEYCHAIN_ACCESS_GROUP"
  case appIdentifierPrefix = "AppIdentifierPrefix"
  case supportURL = "SupportURL"
  case tonkeeperNewsURL = "TonkeeperNewsURL"
  case contactUsURL = "ContactUsURL"
}

public protocol InfoProvider {
  func value<Value>(for key: String) throws -> Value
  func value<Value>(for key: InfoKey) throws -> Value
}

public struct InfoProviderImplemenetation: InfoProvider {
  
  public init() {}
  
  public func value<Value>(for key: String) throws -> Value {
    guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? Value else {
      throw InfoProviderError.failedToGetValue(key: key)
    }
    return value
  }
  
  public func value<Value>(for key: InfoKey) throws -> Value {
    return try value(for: key.rawValue)
  }
}

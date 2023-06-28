//
//  UserDefaultSettings.swift
//  Tonkeeper
//
//  Created by Grigory on 28.6.23..
//

import Foundation

final class AppSettings {
  private let userDefaults = UserDefaults(suiteName: .appSettingsSuiteName)
  
  var didShowOnboarding: Bool {
    get { userDefaults?.bool(forKey: .didShowOnboardingKey) ?? false }
    set { userDefaults?.setValue(newValue, forKey: .didShowOnboardingKey) }
  }
  
  func reset() {
    userDefaults?.removePersistentDomain(forName: .appSettingsSuiteName)
  }
}

private extension String {
  static let appSettingsSuiteName = "AppSettings"
  static let didShowOnboardingKey = "didShowOnboarding"
}

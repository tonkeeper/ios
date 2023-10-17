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
  
  func isFiatMethodPopUpMarkedDoNotShow(for fiatMethodId: String) -> Bool {
    let key = "fiat_method_popup_\(fiatMethodId)"
    return userDefaults?.bool(forKey: key) ?? false
  }
  
  func setIsFiatMethodPopUpMarkedDoNotShow(for fiatMethodId: String, isNeed: Bool) {
    let key = "fiat_method_popup_\(fiatMethodId)"
    userDefaults?.setValue(isNeed, forKey: key)
  }
  
  func reset() {
    userDefaults?.removePersistentDomain(forName: .appSettingsSuiteName)
  }
}

private extension String {
  static let appSettingsSuiteName = "AppSettings"
  static let didShowOnboardingKey = "didShowOnboarding"
}

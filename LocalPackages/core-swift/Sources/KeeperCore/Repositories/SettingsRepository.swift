import Foundation
import CoreComponents

public struct SettingsRepository {
  private let settingsVault: SettingsVault<SettingsKey>
  
  init(settingsVault: SettingsVault<SettingsKey>) {
    self.settingsVault = settingsVault
  }
  
  public var isFirstRun: Bool {
    get {
      settingsVault.value(key: .isFirstRun) ?? true
    }
    set {
      settingsVault.setValue(newValue, key: .isFirstRun)
    }
  }
  
  public var seed: String {
    get {
      settingsVault.value(key: .seed) ?? ""
    }
    set {
      settingsVault.setValue(newValue, key: .seed)
    }
  }
  
  public var didMigrateV2: Bool {
    get {
      settingsVault.value(key: .didMigrateV2) ?? false
    }
    set {
      settingsVault.setValue(newValue, key: .didMigrateV2)
    }
  }
  
  public var didMigrateRN: Bool {
    get {
      settingsVault.value(key: .didMigrateRN) ?? false
    }
    set {
      settingsVault.setValue(newValue, key: .didMigrateRN)
    }
  }
  
  public var isSecureMode: Bool {
    get {
      settingsVault.value(key: .isSecureMode) ?? false
    }
    set {
      settingsVault.setValue(newValue, key: .isSecureMode)
    }
  }
}

public enum SettingsKey: String, CustomStringConvertible {
  public var description: String {
    rawValue
  }
  
  case seed
  case isFirstRun
  case didMigrateV2
  case didMigrateRN
  case isSecureMode
}

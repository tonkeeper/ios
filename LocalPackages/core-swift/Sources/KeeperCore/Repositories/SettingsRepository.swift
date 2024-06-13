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
}

public enum SettingsKey: String, CustomStringConvertible {
  public var description: String {
    rawValue
  }
  
  case seed
  case isFirstRun
}

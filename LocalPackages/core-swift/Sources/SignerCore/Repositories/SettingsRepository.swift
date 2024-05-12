import Foundation
import CoreComponents

public struct SettingsRepository {
  private let settingsVault: SettingsVault<SettingsVaultKey>
  
  init(settingsVault: SettingsVault<SettingsVaultKey>) {
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

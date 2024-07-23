import Foundation
import CoreComponents

public struct CoreAssembly {
  let cacheURL: URL
  let sharedCacheURL: URL
  let appInfoProvider: AppInfoProvider
  
  init(cacheURL: URL, 
       sharedCacheURL: URL,
       appInfoProvider: AppInfoProvider) {
    self.cacheURL = cacheURL
    self.sharedCacheURL = sharedCacheURL
    self.appInfoProvider = appInfoProvider
  }
  
  func mnemonicVault() -> MnemonicVault {
    MnemonicVault(keychainVault: keychainVault, accessGroup: nil)
  }
  
  func mnemonicsV3Vault(seedProvider: @escaping () -> String) -> MnemonicsV3Vault {
    MnemonicsV3Vault(
      keychainVault: keychainVault,
      seedProvider: seedProvider
    )
  }
  
  func passcodeVault() -> PasscodeVault {
    PasscodeVault(keychainVault: keychainVault)
  }
  
  func tonConnectAppsVault() -> TonConnectAppsVault {
    TonConnectAppsVault(keychainVault: keychainVault)
  }

  func fileSystemVault<T, K>() -> FileSystemVault<T, K> {
    return FileSystemVault(fileManager: fileManager, directory: cacheURL)
  }
  
  func sharedFileSystemVault<T, K>() -> FileSystemVault<T, K> {
    return FileSystemVault(fileManager: fileManager, directory: sharedCacheURL)
  }
  
  public var keychainVault: KeychainVault {
    KeychainVaultImplementation(keychain: keychain)
  }
  
  func settingsVault() -> SettingsVault<SettingsKey> {
    return SettingsVault(userDefaults: userDefaults)
  }
}

private extension CoreAssembly {
  var fileManager: FileManager {
    .default
  }
  
  var keychain: Keychain {
    KeychainImplementation()
  }
  
  var userDefaults: UserDefaults {
    UserDefaults.standard
  }
}

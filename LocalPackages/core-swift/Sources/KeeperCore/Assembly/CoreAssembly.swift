import Foundation
import CoreComponents

public struct CoreAssembly {
  let cacheURL: URL
  let sharedCacheURL: URL
  
  init(cacheURL: URL, sharedCacheURL: URL) {
    self.cacheURL = cacheURL
    self.sharedCacheURL = sharedCacheURL
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
  
  var keychainVault: KeychainVault {
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

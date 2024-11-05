import Foundation
import CoreComponents
import TKKeychain

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
  
  func mnemonicsV4Vault() -> MnemonicsV4Vault {
    MnemonicsV4Vault(
      keychainVault: keychainVault
    )
  }

  func tonConnectAppsVault() -> TonConnectAppsVault {
    TonConnectAppsVault(keychainVault: keychainVault)
  }
  
  func tonConnectAppsVaultLegacy() -> TonConnectAppsVaultLegacy {
    TonConnectAppsVaultLegacy(keychainVault: keychainVault)
  }

  func fileSystemVault<T, K>() -> FileSystemVault<T, K> {
    return FileSystemVault(fileManager: fileManager, directory: cacheURL)
  }
  
  func sharedFileSystemVault<T, K>() -> FileSystemVault<T, K> {
    return FileSystemVault(fileManager: fileManager, directory: sharedCacheURL)
  }
  
  public var keychainVault: TKKeychainVault {
    TKKeychainVaultImplementation(keychain: TKKeychainImplementation())
  }
  
  func settingsVault() -> SettingsVault<SettingsKey> {
    return SettingsVault(userDefaults: userDefaults)
  }
}

private extension CoreAssembly {
  var fileManager: FileManager {
    .default
  }
  
  var userDefaults: UserDefaults {
    UserDefaults.standard
  }
}

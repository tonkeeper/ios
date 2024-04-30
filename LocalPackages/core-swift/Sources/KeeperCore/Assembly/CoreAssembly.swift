import Foundation
import CoreComponents

public struct CoreAssembly {
  private let cacheURL: URL
  private let sharedCacheURL: URL
  
  init(cacheURL: URL, sharedCacheURL: URL) {
    self.cacheURL = cacheURL
    self.sharedCacheURL = sharedCacheURL
  }
  
  func mnemonicVault() -> MnemonicVault {
    MnemonicVault(keychainVault: keychainVault, accessGroup: nil)
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
}

private extension CoreAssembly {
  var fileManager: FileManager {
    .default
  }
  
  var keychainVault: KeychainVault {
    KeychainVaultImplementation(keychain: keychain)
  }
  
  var keychain: Keychain {
    KeychainImplementation()
  }
}

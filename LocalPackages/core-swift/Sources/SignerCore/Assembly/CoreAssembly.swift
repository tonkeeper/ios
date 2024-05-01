import Foundation
import CoreComponents

public struct CoreAssembly {
  func mnemonicVault() -> MnemonicVault {
    MnemonicVault(keychainVault: keychainVault, accessGroup: nil)
  }
  
  func passcodeVault() -> PasscodeVault {
    PasscodeVault(keychainVault: keychainVault)
  }
  
  func passwordVault() -> PasswordVault {
    PasswordVault(keychainVault: keychainVault)
  }

  func fileSystemVault<T, K>() -> FileSystemVault<T, K> {
    return FileSystemVault(fileManager: fileManager, directory: cacheURL)
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
  
  var cacheURL: URL {
    documentsURL
  }
  
  var documentsURL: URL {
    let documentsDirectory: URL
    if #available(iOS 16.0, *) {
      documentsDirectory = URL.documentsDirectory
    } else {
      documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    return documentsDirectory
  }
}

import Foundation
import CoreComponents

public struct CoreAssembly {
  func mnemonicVault() -> MnemonicVault {
    MnemonicVault(keychainVault: keychainVault, accessGroup: nil)
  }
  
  func mnemonicsV2Vault(seedProvider: @escaping () -> String) -> MnemonicsV2Vault {
    MnemonicsV2Vault(seedProvider: seedProvider, keychainVault: keychainVault, accessGroup: nil)
  }
  
  func mnemonicsV3Vault(seedProvider: @escaping () -> String) -> MnemonicsV3Vault {
    MnemonicsV3Vault(keychainVault: keychainVault, seedProvider: seedProvider)
  }
  
  func mnemonicsV4Vault() -> MnemonicsV4Vault {
    MnemonicsV4Vault(keychainVault: keychainVault)
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
  
  func settingsVault() -> SettingsVault<SettingsVaultKey> {
    return SettingsVault(userDefaults: userDefaults)
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
  
  var userDefaults: UserDefaults {
    UserDefaults.standard
  }
}

public enum SettingsVaultKey: String, CustomStringConvertible {
  public var description: String {
    rawValue
  }
  
  case seed
  case isFirstRun
}

import CoreComponents
import Foundation
import TKKeychain

public struct CoreAssembly {
    let cacheURL: URL
    let sharedCacheURL: URL
    let appInfoProvider: AppInfoProvider
    let seedProvider: () -> String

    public func rnMnemonicsVault() -> RNMnemonicsVault {
        RNMnemonicsVault(
            keychainVault: keychainVault
        )
    }

    public func mnemonicsVault() -> MnemonicsVault {
        MnemonicsVault(
            keychainVault: keychainVault,
            seedProvider: seedProvider
        )
    }

    func tonConnectAppsVault() -> TonConnectAppsVault {
        TonConnectAppsVault(keychainVault: keychainVault)
    }

    public func fileSystemVault<T, K>() -> FileSystemVault<T, K> {
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

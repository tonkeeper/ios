@testable import KeeperCore
@testable import KeeperCoreComponents
@testable import KeeperCoreSensitive
import TKKeychain

extension MnemonicAccess {
    /// Keychain-free storage that derives keys at test cost; `keychainVault` holds the legacy copy.
    static func inMemory(
        seed: String,
        keychainVault: TKKeychainVault = InMemoryKeychainVault()
    ) -> MnemonicAccess {
        let raw = MnemonicsRawDataRepository(
            seedProvider: { seed },
            keychain: InMemorySecureStorageKeychain(),
            argon2Cost: .testFast
        )
        return MnemonicAccess(
            mnemonicsRepository: ModernRepository(
                raw: raw,
                unlocked: { passcode in
                    try raw.unlocked(passcode: passcode)
                }
            ),
            passcodeStorage: PasscodeStorage(
                seedProvider: { seed },
                keychain: InMemorySecureStorageKeychain()
            ),
            legacyRepository: LegacyRepository(
                rn: RNMnemonicsVault(keychainVault: keychainVault, encryption: .testFast),
                native: MnemonicsVault(keychainVault: keychainVault, seedProvider: { seed }, encryption: .testFast)
            )
        )
    }
}

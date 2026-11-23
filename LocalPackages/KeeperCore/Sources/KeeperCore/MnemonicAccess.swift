import Foundation
import KeeperCoreComponents
import KeeperCoreSensitive
import TKKeychain
import TKLogging

public struct MnemonicAccess {
    public struct LegacyRepository {
        public let rn: RNMnemonicsVault
        public let native: MnemonicsVault
    }

    public struct ModernRepository {
        public let raw: MnemonicsRawDataRepository
        public let unlocked: (_ seed: String) throws -> DefaultMnemonicsRepositoryV2
    }

    public let mnemonicsRepository: ModernRepository
    public let passcodeStorage: PasscodeStorage
    public let legacyRepository: LegacyRepository
    public var didUnlockMnemonics: @Sendable ([CoreMnemonicIdentifier: CoreMnemonic]) async -> Void = { _ in }
}

enum MnemonicAccessError: Swift.Error {
    case passcodeRequired
    case legacyMnemonicInvalid
    case legacyMigrationPending
}

public extension MnemonicAccess {
    func getMnemonic(wallet: Wallet, passcode: String?) async throws -> CoreMnemonic {
        let passcode = try requirePasscode(passcode)
        let unlockedRepository = try mnemonicsRepository.unlocked(passcode)
        let mnemonic = try unlockedRepository.get(id: wallet.id)
        notifyUnlock([wallet.id: mnemonic])
        return mnemonic
    }

    func getMnemonics(wallets: [Wallet], passcode: String?) async throws -> [CoreMnemonicIdentifier: CoreMnemonic] {
        guard !wallets.isEmpty else {
            return [:]
        }
        let passcode = try requirePasscode(passcode)
        let unlockedRepository = try mnemonicsRepository.unlocked(passcode)
        let allMnemonics = try unlockedRepository.getAll()
        let mnemonics = wallets.reduce(into: [CoreMnemonicIdentifier: CoreMnemonic]()) { result, wallet in
            result[wallet.id] = allMnemonics[wallet.id]
        }
        notifyUnlock(mnemonics)
        return mnemonics
    }

    func saveMnemonic(_ mnemonic: CoreMnemonic, wallet: Wallet, passcode: String?) async throws {
        let passcode = try requirePasscode(passcode)
        try mutateV2Storage(passcode: passcode) { mnemonics in
            mnemonics[wallet.id] = mnemonic
        }
        do {
            let legacyMnemonic = try legacyMnemonic(from: mnemonic)
            try await legacyRepository.native.saveMnemonic(legacyMnemonic, wallet: wallet, password: passcode)
        } catch {
            Log.e("🪵 failed to save mnemonic (legacy) due to: \(error)")
        }
    }

    func saveMnemonic(_ mnemonic: CoreMnemonic, wallets: [Wallet], passcode: String?) async throws {
        let passcode = try requirePasscode(passcode)
        try mutateV2Storage(passcode: passcode) { mnemonics in
            for wallet in wallets {
                mnemonics[wallet.id] = mnemonic
            }
        }
        do {
            let legacyMnemonic = try legacyMnemonic(from: mnemonic)
            try await legacyRepository.native.saveMnemonic(legacyMnemonic, wallets: wallets, password: passcode)
        } catch {
            Log.e("🪵 failed to save (batch) mnemonic (legacy) due to: \(error)")
        }
    }

    func deleteMnemonic(wallet: Wallet, passcode: String?) async throws {
        let resolvedPasscode: String
        if let passcode {
            resolvedPasscode = passcode
        } else {
            do {
                resolvedPasscode = try passcodeStorage.getPasscode()
            } catch {
                throw MnemonicAccessError.passcodeRequired
            }
        }
        try deleteV2Mnemonic(id: wallet.id, passcode: resolvedPasscode)
        do {
            try await legacyRepository.native.deleteMnemonic(wallet: wallet, password: resolvedPasscode)
        } catch {
            Log.e("🪵 failed to delete mnemonic (legacy) due to: \(error)")
        }
    }

    func deletePasscode() throws {
        try passcodeStorage.deletePasscode()
        do {
            try legacyRepository.native.deletePassword()
        } catch TKKeychainError.noItem {
        } catch {
            Log.e("🪵 passcode removal (legacy) failed: \(error)")
        }
    }

    func validatePasscode(_ passcode: String) async -> Bool {
        do {
            let mnemonics = try mnemonicsRepository.unlocked(passcode).getAll()
            notifyUnlock(mnemonics)
            return true
        } catch {
            Log.i("🪵 passcode validation failed: \(error)")
            return false
        }
    }

    func changePasscode(old: String, new: String) async throws {
        try mnemonicsRepository.raw.changePasscode(old: old, new: new)
        do {
            try await legacyRepository.native.changePassword(oldPassword: old, newPassword: new)
        } catch {
            Log.e("🪵 legacy passcode change failed: \(error)")
        }
    }

    func hasMnemonics() -> Bool {
        do {
            return try mnemonicsRepository.raw.hasMnemonic()
        } catch {
            Log.e("🪵 has mnemonics check failed: \(error)")
            return false
        }
    }

    func getPasscode() throws -> String {
        try passcodeStorage.getPasscode()
    }

    /// Probes the biometry-protected passcode item without prompting, so a
    /// failed biometric unlock can tell an invalidated enrolled set apart from a
    /// plain failed match.
    func biometryAccessProbe() -> BiometryAccessState {
        let probed = passcodeStorage.probeBiometryAccess()
        switch probed {
        case .accessible, .invalidated, .indeterminate:
            // `.indeterminate` is an *unexpected* keychain error: keep it as-is so
            // a transient failure on a healthy device is not mistaken for an
            // enrollment change (consumers treat non-`.invalidated` conservatively).
            return probed
        case .missing:
            // On device an invalidated biometryCurrentSet item reads as not-found
            // (errSecItemNotFound), indistinguishable from a truly absent item by
            // status alone. The non-biometric "migrated" marker disambiguates:
            // it is written next to the cache and removed together with it, and an
            // enrollment change cannot touch it. Marker present means the cache
            // existed and is now invalidated; marker absent means it is genuinely
            // gone and the enrolled set never changed. A present wallet (mnemonics,
            // stored without biometry) confirms the cache was in use.
            guard isBiometryItemMigrated() else {
                return .missing
            }
            return hasMnemonics() ? .invalidated : .missing
        }
    }

    /// Whether biometry has no cache left to unlock: no known storage holds a
    /// biometry-protected passcode, and none holds a marker for one either, so
    /// nothing was invalidated by an enrollment change — the cache was discarded.
    ///
    /// The v2 storage alone cannot answer this: until the native->v2 migration
    /// runs, its passcode storage is empty while the legacy cache is live and
    /// about to be migrated into it.
    func isBiometryCacheDiscarded() -> Bool {
        let legacy = legacyRepository.native
        let isLegacyCacheDiscarded = legacy.probeBiometryAccess().biometryAccessState == .missing
            && !legacy.isBiometryItemMigrated()
        return isLegacyCacheDiscarded
            && passcodeStorage.probeBiometryAccess() == .missing
            && !passcodeStorage.isBiometryItemMigrated()
    }

    /// Whether the biometry-protected password item already uses
    /// `biometryCurrentSet`. A missing marker means a legacy `biometryAny` item
    /// still needs the one-time migration, performed by re-saving the password on
    /// the next successful unlock.
    func isBiometryItemMigrated() -> Bool {
        passcodeStorage.isBiometryItemMigrated()
    }

    func setPasscode(_ passcode: String) throws {
        try passcodeStorage.setPasscode(passcode)
        do {
            try legacyRepository.native.deletePassword()
        } catch TKKeychainError.noItem {
        } catch {
            Log.e("🪵 legacy passcode removal after v2 passcode save failed: \(error)")
        }
    }
}

private extension TKKeychainBiometryAccess {
    var biometryAccessState: BiometryAccessState {
        switch self {
        case .accessible: return .accessible
        case .invalidated: return .invalidated
        case .missing: return .missing
        case .indeterminate: return .indeterminate
        }
    }
}

private extension MnemonicAccess {
    func notifyUnlock(_ mnemonics: [CoreMnemonicIdentifier: CoreMnemonic]) {
        let notify = didUnlockMnemonics
        Task { await notify(mnemonics) }
    }

    func requirePasscode(_ passcode: String?) throws -> String {
        guard let passcode else {
            throw MnemonicAccessError.passcodeRequired
        }
        return passcode
    }

    func legacyMnemonic(from mnemonic: CoreMnemonic) throws -> KeeperCoreComponents.Mnemonic {
        do {
            return try KeeperCoreComponents.Mnemonic(mnemonicWords: mnemonic.mnemonicWords)
        } catch {
            throw MnemonicAccessError.legacyMnemonicInvalid
        }
    }

    func mutateV2Storage(
        passcode: String,
        mutation: (inout [CoreMnemonicIdentifier: CoreMnemonic]) throws -> Void
    ) throws {
        let rawStorage = mnemonicsRepository.raw
        let mnemonics: [CoreMnemonicIdentifier: CoreMnemonic]
        if try rawStorage.hasCommittedStorage() {
            let repository = try rawStorage.unlocked(passcode: passcode)
            mnemonics = try repository.getAll()
        } else {
            // No committed v2 storage next to a non-empty legacy vault means the
            // native->v2 migration has not run or has failed. Committing v2 here
            // would make the migration check consider it done, and the legacy
            // dual-write that follows would overwrite the vault under a passcode
            // that cannot decrypt it. Refuse; a relaunch retries the migration.
            guard !legacyRepository.native.holdsMnemonics() else {
                Log.e("🪵 refused to create v2 mnemonics storage: legacy vault is not migrated yet")
                throw MnemonicAccessError.legacyMigrationPending
            }
            mnemonics = [:]
        }
        var updatedMnemonics = mnemonics
        try mutation(&updatedMnemonics)
        try rawStorage.rewrite(
            mnemonics: updatedMnemonics,
            passcode: passcode
        )
    }

    func deleteV2Mnemonic(
        id: CoreMnemonicIdentifier,
        passcode: String
    ) throws {
        let rawStorage = mnemonicsRepository.raw
        guard try rawStorage.hasCommittedStorage() else {
            return
        }
        guard try rawStorage.hasMnemonic() else {
            return
        }
        let repository = try rawStorage.unlocked(passcode: passcode)
        var mnemonics = try repository.getAll()
        guard mnemonics.removeValue(forKey: id) != nil else {
            return
        }
        let shouldDeletePasscode = mnemonics.isEmpty
        try rawStorage.rewrite(
            mnemonics: mnemonics,
            passcode: passcode
        )
        if shouldDeletePasscode {
            do {
                try passcodeStorage.deleteAllKnownStorageArtifacts()
            } catch {
                Log.e("failed to delete passcode data on cleanup mnemonics data due to error: \(error)")
            }
        }
    }
}

import Foundation
import KeeperCoreComponents
import KeeperCoreSensitive
import TKKeychain
import TKLogging

public enum MnemonicAccess {
    public struct LegacyRepository {
        public let rn: RNMnemonicsVault
        public let native: MnemonicsVault
    }

    public struct ModernRepository {
        public let raw: MnemonicsRawDataRepository
        public let unlocked: (_ seed: String) throws -> DefaultMnemonicsRepositoryV2
    }

    case v2(
        mnemonicsRepository: ModernRepository,
        passcodeStorage: PasscodeStorage,
        legacyRepository: LegacyRepository
    )
    case disabled(
        mnemonicsRepository: LegacyRepository
    )

    public var legacyRepository: LegacyRepository {
        switch self {
        case let .v2(_, _, legacyRepository), let .disabled(legacyRepository):
            legacyRepository
        }
    }
}

enum MnemonicAccessError: Swift.Error {
    case passcodeRequired
    case legacyMnemonicInvalid
}

public extension MnemonicAccess {
    func getMnemonic(wallet: Wallet, passcode: String?) async throws -> CoreMnemonic {
        switch self {
        case let .v2(mnemonicsRepositoryV2, _, _):
            let passcode = try requirePasscode(passcode)
            let unlockedRepository = try mnemonicsRepositoryV2.unlocked(passcode)
            return try unlockedRepository.get(id: wallet.id)
        case let .disabled(mnemonicsRepository):
            let passcode = try requirePasscode(passcode)
            let mnemonic = try await mnemonicsRepository.native.getMnemonic(wallet: wallet, password: passcode)
            return CoreMnemonic(
                mnemonicWords: mnemonic.mnemonicWords,
                type: derivationType(words: mnemonic.mnemonicWords, wallet: wallet)
            )
        }
    }

    func getMnemonics(wallets: [Wallet], passcode: String?) async throws -> [CoreMnemonicIdentifier: CoreMnemonic] {
        guard !wallets.isEmpty else {
            return [:]
        }
        switch self {
        case let .v2(mnemonicsRepositoryV2, _, _):
            let passcode = try requirePasscode(passcode)
            let unlockedRepository = try mnemonicsRepositoryV2.unlocked(passcode)
            let allMnemonics = try unlockedRepository.getAll()
            return wallets.reduce(into: [:]) { result, wallet in
                result[wallet.id] = allMnemonics[wallet.id]
            }
        case let .disabled(mnemonicsRepository):
            let passcode = try requirePasscode(passcode)
            var result = [CoreMnemonicIdentifier: CoreMnemonic]()
            for wallet in wallets {
                do {
                    let mnemonic = try await mnemonicsRepository.native.getMnemonic(wallet: wallet, password: passcode)
                    result[wallet.id] = CoreMnemonic(
                        mnemonicWords: mnemonic.mnemonicWords,
                        type: derivationType(words: mnemonic.mnemonicWords, wallet: wallet)
                    )
                } catch {
                    Log.w("🪵 failed to load legacy mnemonic for batch read. id=\(wallet.id), error=\(error)")
                }
            }
            return result
        }
    }

    func saveMnemonic(_ mnemonic: CoreMnemonic, wallet: Wallet, passcode: String?) async throws {
        let saveMnemonicLegacy: (MnemonicsRepository) async throws -> Void = { repository in
            let passcode = try requirePasscode(passcode)
            let legacyMnemonic = try legacyMnemonic(from: mnemonic)
            try await repository.saveMnemonic(legacyMnemonic, wallet: wallet, password: passcode)
        }
        switch self {
        case let .v2(mnemonicsRepositoryV2, _, legacyRepository):
            let passcode = try requirePasscode(passcode)
            try mutateV2Storage(
                rawStorage: mnemonicsRepositoryV2.raw,
                passcode: passcode
            ) { mnemonics in
                mnemonics[wallet.id] = mnemonic
            }
            do {
                try await saveMnemonicLegacy(legacyRepository.native)
            } catch {
                Log.e("🪵 failed to save mnemonic (legacy) due to: \(error)")
            }
        case let .disabled(mnemonicsRepository):
            try await saveMnemonicLegacy(mnemonicsRepository.native)
        }
    }

    func saveMnemonic(_ mnemonic: CoreMnemonic, wallets: [Wallet], passcode: String?) async throws {
        let saveMnemonicLegacy: (MnemonicsRepository) async throws -> Void = { repository in
            let passcode = try requirePasscode(passcode)
            let legacyMnemonic = try legacyMnemonic(from: mnemonic)
            try await repository.saveMnemonic(legacyMnemonic, wallets: wallets, password: passcode)
        }
        switch self {
        case let .v2(mnemonicsRepositoryV2, _, legacyMnemonicsRepository):
            let passcode = try requirePasscode(passcode)
            try mutateV2Storage(
                rawStorage: mnemonicsRepositoryV2.raw,
                passcode: passcode
            ) { mnemonics in
                for wallet in wallets {
                    mnemonics[wallet.id] = mnemonic
                }
            }
            do {
                try await saveMnemonicLegacy(legacyMnemonicsRepository.native)
            } catch {
                Log.e("🪵 failed to save (batch) mnemonic (legacy) due to: \(error)")
            }
        case let .disabled(mnemonicsRepository):
            try await saveMnemonicLegacy(mnemonicsRepository.native)
        }
    }

    func deleteMnemonic(wallet: Wallet, passcode: String?) async throws {
        let deleteMnemonicLegacy: (MnemonicsRepository, String?) async throws -> Void = { repository, resolvedPasscode in
            let passcode = resolvedPasscode ?? passcode ?? (try? repository.getPassword())
            let resolvedPasscode = try requirePasscode(passcode)
            try await repository.deleteMnemonic(wallet: wallet, password: resolvedPasscode)
        }
        switch self {
        case let .v2(mnemonicsRepositoryV2, passcodeStorage, legacyMnemonicsRepository):
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
            try deleteV2Mnemonic(
                rawStorage: mnemonicsRepositoryV2.raw,
                passcodeStorage: passcodeStorage,
                id: wallet.id,
                passcode: resolvedPasscode
            )
            do {
                try await deleteMnemonicLegacy(legacyMnemonicsRepository.native, resolvedPasscode)
            } catch {
                Log.e("🪵 failed to delete mnemonic (legacy) due to: \(error)")
            }
        case let .disabled(mnemonicsRepository):
            try await deleteMnemonicLegacy(mnemonicsRepository.native, nil)
        }
    }

    func deleteAll(passcode: String?) async throws {
        let deleteMnemonicLegacy: (MnemonicsRepository) async throws -> Void = { repository in
            try await repository.deleteAll()
        }
        switch self {
        case let .v2(mnemonicsRepositoryV2, passcodeStorage, legacyMnemonicsRepository):
            do {
                try mnemonicsRepositoryV2.raw.deleteAllKnownStorageArtifacts()
            } catch {
                Log.e("🪵 failed to delete all v2 mnemonic artifacts due to: \(error)")
                throw error
            }
            do {
                try passcodeStorage.deleteAllKnownStorageArtifacts()
            } catch {
                Log.e("🪵 failed to delete v2 passcode due to: \(error)")
            }
            do {
                try await deleteMnemonicLegacy(legacyMnemonicsRepository.native)
            } catch {
                Log.e("🪵 failed to delete (all) mnemonic (legacy) due to: \(error)")
            }
        case let .disabled(mnemonicsRepository):
            try await deleteMnemonicLegacy(mnemonicsRepository.native)
        }
    }

    func deletePasscode() throws {
        let deletePasscodeLegacy: (MnemonicsRepository) throws -> Void = { repository in
            try repository.deletePassword()
        }
        switch self {
        case let .v2(_, passcodeStorage, mnemonicsRepository):
            try passcodeStorage.deletePasscode()
            do {
                try deletePasscodeLegacy(mnemonicsRepository.native)
            } catch TKKeychainError.noItem {
            } catch {
                Log.e("🪵 passcode removal (legacy) failed: \(error)")
            }
        case let .disabled(mnemonicsRepository):
            try deletePasscodeLegacy(mnemonicsRepository.native)
        }
    }

    func validatePasscode(_ passcode: String) async -> Bool {
        switch self {
        case let .v2(repository, _, _):
            do {
                _ = try repository.unlocked(passcode).getAll()
                return true
            } catch {
                Log.i("🪵 passcode validation failed: \(error)")
                return false
            }
        case let .disabled(mnemonicsRepository):
            return await mnemonicsRepository.native.checkIfPasswordValid(passcode)
        }
    }

    func changePasscode(old: String, new: String) async throws {
        let legacyChangePasscode: (MnemonicsRepository) async throws -> Void = { mnemonicsRepository in
            try await mnemonicsRepository.changePassword(oldPassword: old, newPassword: new)
        }
        switch self {
        case let .v2(mnemonicsRepository, _, legacyRepository):
            try mnemonicsRepository.raw.changePasscode(old: old, new: new)
            do {
                try await legacyChangePasscode(legacyRepository.native)
            } catch {
                Log.e("🪵 legacy passcode change failed: \(error)")
            }
        case .disabled:
            try await legacyChangePasscode(legacyRepository.native)
        }
    }

    func hasMnemonics() -> Bool {
        switch self {
        case let .v2(mnemonicsRepositoryV2, _, _):
            do {
                return try mnemonicsRepositoryV2.raw.hasMnemonic()
            } catch {
                Log.e("🪵 has mnemonics check failed: \(error)")
                return false
            }
        case let .disabled(mnemonicsRepository):
            return mnemonicsRepository.native.hasMnemonics()
        }
    }

    func getPasscode() throws -> String {
        switch self {
        case let .v2(_, passcodeStorage, _):
            try passcodeStorage.getPasscode()
        case let .disabled(mnemonicsRepository):
            try mnemonicsRepository.native.getPassword()
        }
    }

    /// Probes the biometry-protected passcode item without prompting, so a
    /// failed biometric unlock can tell an invalidated enrolled set apart from a
    /// plain failed match. The legacy (non-v2) password item is also protected
    /// with `biometryCurrentSet`, so it is probed the same way.
    func biometryAccessProbe() -> BiometryAccessState {
        let probed: BiometryAccessState
        switch self {
        case let .v2(_, passcodeStorage, _):
            probed = passcodeStorage.probeBiometryAccess()
        case let .disabled(mnemonicsRepository):
            probed = mnemonicsRepository.native.probeBiometryAccess().biometryAccessState
        }
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
            // gone — a storage-version rollback discards it, and the enrolled set
            // never changed. A present wallet (mnemonics, stored without biometry)
            // confirms the cache was in use. Applies to both storages.
            guard isBiometryItemMigrated() else {
                return .missing
            }
            return hasMnemonics() ? .invalidated : .missing
        }
    }

    /// Whether biometry has no cache left to unlock: no known storage holds a
    /// biometry-protected passcode, and none holds a marker for one either, so
    /// nothing was invalidated by an enrollment change — the cache was discarded,
    /// as a storage-version switch does (the passcode lives in the storage being
    /// switched away from).
    ///
    /// The active storage alone cannot answer this: right after storage v2 is
    /// enabled its passcode storage is still empty while the legacy cache is live
    /// and about to be migrated into it.
    func isBiometryCacheDiscarded() -> Bool {
        let legacy = legacyRepository.native
        let isLegacyCacheDiscarded = legacy.probeBiometryAccess().biometryAccessState == .missing
            && !legacy.isBiometryItemMigrated()
        switch self {
        case let .v2(_, passcodeStorage, _):
            return isLegacyCacheDiscarded
                && passcodeStorage.probeBiometryAccess() == .missing
                && !passcodeStorage.isBiometryItemMigrated()
        case .disabled:
            return isLegacyCacheDiscarded
        }
    }

    /// Whether the biometry-protected password item already uses
    /// `biometryCurrentSet`. A missing marker means a legacy `biometryAny` item
    /// still needs the one-time migration, performed by re-saving the password on
    /// the next successful unlock.
    func isBiometryItemMigrated() -> Bool {
        switch self {
        case let .v2(_, passcodeStorage, _):
            passcodeStorage.isBiometryItemMigrated()
        case let .disabled(mnemonicsRepository):
            mnemonicsRepository.native.isBiometryItemMigrated()
        }
    }

    func setPasscode(_ passcode: String) throws {
        let setPasscodeLegacy: (MnemonicsRepository) throws -> Void = { repository in
            try repository.savePassword(passcode)
        }
        switch self {
        case let .v2(_, passcodeStorage, legacyRepository):
            try passcodeStorage.setPasscode(passcode)
            do {
                try legacyRepository.native.deletePassword()
            } catch TKKeychainError.noItem {
            } catch {
                Log.e("🪵 legacy passcode removal after v2 passcode save failed: \(error)")
            }
        case let .disabled(mnemonicsRepository):
            try setPasscodeLegacy(mnemonicsRepository.native)
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
    func derivationType(words: [String], wallet: Wallet) -> DerivationType {
        do {
            let publicKey = try wallet.publicKey
            return DerivationType.resolveByWords(words, publicKey: publicKey)
        } catch {
            Log.w("🪵 failed to read wallet public key for mnemonic type resolution. id=\(wallet.id), error=\(error)")
            return .guessByWords(words)
        }
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
        rawStorage: MnemonicsRawDataRepository,
        passcode: String,
        mutation: (inout [CoreMnemonicIdentifier: CoreMnemonic]) throws -> Void
    ) throws {
        let mnemonics: [CoreMnemonicIdentifier: CoreMnemonic]
        if try rawStorage.hasCommittedStorage() {
            let repository = try rawStorage.unlocked(passcode: passcode)
            mnemonics = try repository.getAll()
        } else {
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
        rawStorage: MnemonicsRawDataRepository,
        passcodeStorage: PasscodeStorage,
        id: CoreMnemonicIdentifier,
        passcode: String
    ) throws {
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

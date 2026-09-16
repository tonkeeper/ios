import CryptoKit
import Foundation
import LocalAuthentication
import Security
import TKLogging

public enum PasscodeStorageFailure: Error {
    case encodeFailure(message: String)
    case securityFailure(code: OSStatus)
    case storageFailure(underlying: Error)
    case decodeFailure(message: String)
    case notFound
}

/// Outcome of a non-interactive probe of the biometry-protected passcode item.
public enum BiometryAccessState {
    /// Access control still satisfiable — the item is present and a real unlock
    /// would prompt for biometry.
    case accessible
    /// Access control can no longer be satisfied — the enrolled biometric set
    /// changed, invalidating the item.
    case invalidated
    /// No biometry-protected passcode item exists.
    case missing
    /// Could not determine (unexpected keychain error).
    case indeterminate
}

public struct PasscodeStorage {
    let seedProvider: () -> String

    private let keychain: SecureStorageKeychain

    public init(seedProvider: @escaping () -> String) {
        self.init(
            seedProvider: seedProvider,
            keychain: SystemSecureStorageKeychain()
        )
    }

    init(
        seedProvider: @escaping () -> String,
        keychain: SecureStorageKeychain
    ) {
        self.seedProvider = seedProvider
        self.keychain = keychain
    }
}

// MARK: - Public API

public extension PasscodeStorage {
    private var passcodeCoding: PasscodeCoding {
        PasscodeCoding()
    }

    func setPasscode(_ passcode: String) throws(PasscodeStorageFailure) {
        let encrypted: EncodedPasscode
        do {
            encrypted = try passcodeCoding.encoder.encryptPasscode(passcode)
        } catch {
            switch error {
            case let .wrapKeyGenerationFailure(message):
                throw .encodeFailure(
                    message: "passcode encoding failed, failed to generate wrap key: \(message)"
                )
            case let .encryptionFailure(message):
                throw .encodeFailure(
                    message: "passcode encoding failed, failed to encrypt: \(message)"
                )
            }
        }
        let accessControl = try createWrapKeyAccessControl()
        try writePasscode(
            input: .set(
                PasscodeStorageSlotStorage.SetInput(
                    wrapKey: encrypted.wrapKey,
                    encryptedPayload: encrypted.encryptedPayload,
                    accessControl: accessControl
                )
            )
        )
        // The wrap key was just (re)created with biometryCurrentSet, so record
        // that the legacy biometryAny migration is done. The unlock path reads
        // this marker to avoid re-encrypting on every successful unlock.
        markBiometryItemMigrated()
    }

    /// Whether the biometry-protected wrap key is known to use the
    /// `biometryCurrentSet` access control. Every `setPasscode` (re)creates the
    /// item with `biometryCurrentSet` and writes this marker, so a missing marker
    /// means a legacy `biometryAny` wrap key still needs a one-time migration.
    func isBiometryItemMigrated() -> Bool {
        let status = keychain.copyMatching(
            biometryMigratedMarkerQuery() as CFDictionary,
            result: nil
        )
        switch status {
        case errSecSuccess:
            return true
        case errSecItemNotFound:
            return false
        default:
            // Be conservative: an unexpected error must not strand a legacy
            // biometryAny item unmigrated, so report not-migrated and let the
            // unlock path re-create the wrap key with biometryCurrentSet.
            Log.e("Biometry migration marker read failed, error code: \(status)")
            return false
        }
    }

    /// Probes the biometry-protected passcode item without prompting, so a
    /// failed biometric unlock can tell an invalidated enrolled set apart from a
    /// plain failed match.
    func probeBiometryAccess() -> BiometryAccessState {
        let storage: PasscodeStorageSlotStorage?
        do {
            storage = try abSlotCoordinator.activeStorage()
        } catch {
            return .indeterminate
        }
        guard let storage else { return .missing }
        return storage.probeBiometryAccess()
    }

    func hasPasscode() -> Bool {
        do {
            return try abSlotCoordinator.hasData()
        } catch {
            Log.e("Passcode presence check failed: \(passcodeFailure(from: error))")
            return false
        }
    }

    func deletePasscode() throws(PasscodeStorageFailure) {
        try writePasscode(input: .delete)
        // Clear the migration marker too (matching deleteAllKnownStorageArtifacts),
        // so a deleted passcode never leaves a stale "migrated" flag behind.
        try? removeBiometryMigratedMarker()
    }

    func deleteAllKnownStorageArtifacts() throws(PasscodeStorageFailure) {
        let removeSlotFailures = ABStorageSlot.allCases
            .map { slot in
                executeAndReturnErrorIfAny { () throws(PasscodeStorageFailure) in
                    try cleanup(slot: slot)
                }
            }
        let removeLegacyFailure = [
            executeAndReturnErrorIfAny { () throws(PasscodeStorageFailure) in
                try removeLegacyArtifacts()
            },
            executeAndReturnErrorIfAny { () throws(PasscodeStorageFailure) in
                try deleteActiveStorageSlot()
            },
        ]
        // The marker is a recreatable flag, not passcode data: losing it only
        // costs one idempotent wrap-key re-create. Failing to remove it must not
        // fail the caller's cleanup — `deletePasscode()` treats it the same way.
        _ = executeAndReturnErrorIfAny { () throws(PasscodeStorageFailure) in
            try removeBiometryMigratedMarker()
        }
        let failures = (removeSlotFailures + removeLegacyFailure).compactMap { $0 }
        guard let failure = failures.first else {
            return
        }
        throw failure
    }

    func getPasscode() throws(PasscodeStorageFailure) -> String {
        let storage: PasscodeStorageSlotStorage?
        do {
            storage = try abSlotCoordinator.activeStorage()
        } catch {
            throw passcodeFailure(from: error)
        }
        guard let storage else {
            throw .notFound
        }
        let encryptedPayload = try storage.encryptedPasscodePayload()
        let context = LAContext()
        let wrapKey = try storage.readWrapKey(context: context)

        let passcode: String
        do {
            passcode = try passcodeCoding
                .decoder
                .decode(encryptedPayload, with: wrapKey)
        } catch {
            switch error {
            case .invalidData:
                throw .decodeFailure(
                    message: "failed to decode password data: encoded data is invalid"
                )
            case .wrongPasscode:
                throw .decodeFailure(
                    message: "failed to decode password data: wrond credentials"
                )
            }
        }
        return passcode
    }
}

// MARK: - Internal

private extension PasscodeStorage {
    private func writePasscode(
        input: PasscodeStorageSlotStorage.WriteInput
    ) throws(PasscodeStorageFailure) {
        let commit: ABSlotCommit<PasscodeStorageSlotStorage>
        do {
            commit = try abSlotCoordinator.commit(input)
        } catch {
            throw passcodeFailure(from: error)
        }

        do {
            try commit.previousStorage?.prepare()
        } catch {
            Log.e("Passcode previous slot cleanup failed after A/B commit. error=\(error)")
        }
    }

    private func passcodeFailure(
        from error: ABSlotCoordinatorFailure<PasscodeStorageFailure>
    ) -> PasscodeStorageFailure {
        switch error {
        case let .activeSlot(error):
            return passcodeError(from: error)
        case let .storage(error):
            return error
        case let .unexpectedStagedSlot(expected, actual):
            Log.e("Unexpected passcode staged slot. expected=\(expected), actual=\(actual)")
            return .securityFailure(code: errSecInternalComponent)
        case .stagedDiscardFailed,
             .activationCleanupFailed:
            return .storageFailure(underlying: error)
        }
    }

    private func passcodeError(from error: ABActiveSlotKeychainStore.Error) -> PasscodeStorageFailure {
        switch error {
        case let .unexpectedStatus(status):
            Log.e("Active passcode slot access failed, keychain error code: \(status)")
            return .securityFailure(code: status)
        case .invalidData:
            return .decodeFailure(message: "invalid data")
        }
    }

    private func deleteActiveStorageSlot() throws(PasscodeStorageFailure) {
        do {
            try activeSlotStore.deleteActiveSlot()
        } catch {
            switch error {
            case let .unexpectedStatus(status):
                throw .securityFailure(code: status)
            case .invalidData:
                throw .decodeFailure(message: "invalid data")
            }
        }
    }

    private func createWrapKeyAccessControl() throws(PasscodeStorageFailure) -> SecAccessControl {
        var error: Unmanaged<CFError>?
        guard let accessControl = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryCurrentSet,
            &error
        ) else {
            throw .securityFailure(code: osStatus(from: error))
        }
        return accessControl
    }

    private func osStatus(
        from error: Unmanaged<CFError>?
    ) -> OSStatus {
        guard let error else {
            return errSecInternalComponent
        }
        let cfError = error.takeRetainedValue()
        return OSStatus(CFErrorGetCode(cfError))
    }
}

// MARK: - Slots

private extension PasscodeStorage {
    private var activeSlotStore: ABActiveSlotKeychainStore {
        ABActiveSlotKeychainStore(
            serviceKey: serviceKey,
            keychainWriteAccessType: keychainWriteAccessType,
            keychain: keychain
        )
    }

    private var abSlotCoordinator: ABSlotCoordinator<PasscodeStorageSlotStorage> {
        ABSlotCoordinator(
            activeSlotStore: activeSlotStore,
            makeStorage: { slot in
                PasscodeStorageSlotStorage(
                    keychain: keychain,
                    slot: slot,
                    keychainQuery: {
                        keychainQuery(for: $0)
                    },
                    cleanup: { () throws(PasscodeStorageFailure) in
                        try cleanup(slot: slot)
                    }
                )
            }
        )
    }
}

// MARK: - Cleanup

private extension PasscodeStorage {
    func cleanup(slot: ABStorageSlot) throws(PasscodeStorageFailure) {
        try executeRemoveQueries([
            .removeEncryptedPasscode(slot: slot),
            .removeWrapKey(slot: slot),
        ])
    }

    func removeLegacyArtifacts() throws(PasscodeStorageFailure) {
        try executeRemoveQueries([
            .removeEncryptedPasscodeLegacy,
            .removeWrapKeyLegacy,
        ])
    }

    /// Records that the wrap key uses `biometryCurrentSet`. Best-effort: the
    /// passcode is already saved, so a marker write failure only costs one extra
    /// (idempotent) wrap-key re-create on the next unlock.
    func markBiometryItemMigrated() {
        let status = keychain.add(
            biometryMigratedMarkerAddQuery() as CFDictionary,
            result: nil
        )
        switch status {
        case errSecSuccess, errSecDuplicateItem:
            return
        default:
            Log.e("Failed to write biometry migration marker, error code: \(status)")
        }
    }

    func removeBiometryMigratedMarker() throws(PasscodeStorageFailure) {
        let status = keychain.delete(
            biometryMigratedMarkerQuery() as CFDictionary
        )
        switch status {
        case errSecSuccess, errSecItemNotFound:
            return
        default:
            Log.e("Failed to remove biometry migration marker, error code: \(status)")
            throw .securityFailure(code: status)
        }
    }

    func executeRemoveQueries(
        _ queries: [PasscodeStorageKeychainQuery]
    ) throws(PasscodeStorageFailure) {
        let failures: [PasscodeStorageFailure] = queries
            .compactMap { query in
                let status = keychain.delete(
                    keychainQuery(
                        for: query
                    ) as CFDictionary
                )
                switch status {
                case errSecSuccess, errSecItemNotFound:
                    return nil
                default:
                    Log.e("failed to remove passcode slot due to keychain error: \(status)")
                    return .securityFailure(code: status)
                }
            }
        guard let first = failures.first else {
            return
        }
        throw first
    }

    func executeAndReturnErrorIfAny(
        _ closure: () throws(PasscodeStorageFailure) -> Void
    ) -> PasscodeStorageFailure? {
        do {
            try closure()
        } catch {
            return error
        }
        return nil
    }
}

// MARK: - Keychain helpers

private extension PasscodeStorage {
    func keychainQuery(
        for type: PasscodeStorageKeychainQuery
    ) -> [CFString: Any] {
        let service = serviceKey
        switch type {
        case let .checkEncryptedPasscode(slot):
            return [
                kSecClass: securityClass,
                kSecAttrService: service,
                kSecAttrAccount: encryptedPasscodeAccountKey(slot: slot),
                kSecMatchLimit: kSecMatchLimitOne,
                kSecReturnAttributes: true as AnyObject,
            ]
        case let .addEncryptedPasscode(value, slot):
            return [
                kSecClass: securityClass,
                kSecAttrAccessible: keychainWriteAccessType,
                kSecAttrService: service,
                kSecAttrAccount: encryptedPasscodeAccountKey(slot: slot),
                kSecValueData: value as AnyObject,
            ]
        case let .getEncryptedPasscode(slot):
            return [
                kSecClass: securityClass,
                kSecAttrService: service,
                kSecAttrAccount: encryptedPasscodeAccountKey(slot: slot),
                kSecMatchLimit: kSecMatchLimitOne,
                kSecReturnData: true as AnyObject,
            ]
        case let .updateEncryptedPasscode(slot),
             let .removeEncryptedPasscode(slot):
            return [
                kSecClass: securityClass,
                kSecAttrService: service,
                kSecAttrAccount: encryptedPasscodeAccountKey(slot: slot),
            ]
        case let .checkWrapKey(context, slot):
            return [
                kSecClass: securityClass,
                kSecAttrService: service,
                kSecAttrAccount: wrapKeyAccountKey(slot: slot),
                kSecMatchLimit: kSecMatchLimitOne,
                kSecReturnAttributes: true as AnyObject,
                kSecUseAuthenticationContext: context,
            ]
        case let .addWrapKey(value, accessControl, slot):
            return [
                kSecClass: securityClass,
                kSecAttrService: service,
                kSecAttrAccount: wrapKeyAccountKey(slot: slot),
                kSecAttrAccessControl: accessControl,
                kSecValueData: value as AnyObject,
            ]
        case let .getWrapKey(context, slot):
            return [
                kSecClass: securityClass,
                kSecAttrService: service,
                kSecAttrAccount: wrapKeyAccountKey(slot: slot),
                kSecMatchLimit: kSecMatchLimitOne,
                kSecReturnData: true as AnyObject,
                kSecUseAuthenticationContext: context,
            ]
        case let .updateWrapKey(slot),
             let .removeWrapKey(slot):
            return [
                kSecClass: securityClass,
                kSecAttrService: service,
                kSecAttrAccount: wrapKeyAccountKey(slot: slot),
            ]
        case .removeWrapKeyLegacy:
            return [
                kSecClass: securityClass,
                kSecAttrService: service,
                kSecAttrAccount: Keys.wrapKeyAccountKey,
            ]
        case .removeEncryptedPasscodeLegacy:
            return [
                kSecClass: securityClass,
                kSecAttrService: service,
                kSecAttrAccount: Keys.encryptedPasscodeAccountKey,
            ]
        }
    }

    /// Non-biometric presence query for the migration marker. The marker is a
    /// plain generic-password item (no secret), kept in the keychain alongside
    /// the wrap key so it shares the wrap key's persistence domain.
    /// Also used to delete the marker, so it must carry no match or return keys:
    /// `SecItemDelete` rejects those with `errSecParam`, and `kSecMatchLimitOne`
    /// is already `SecItemCopyMatching`'s default.
    func biometryMigratedMarkerQuery() -> [CFString: Any] {
        [
            kSecClass: securityClass,
            kSecAttrService: serviceKey,
            kSecAttrAccount: Keys.biometryMigratedAccountKey,
        ]
    }

    func biometryMigratedMarkerAddQuery() -> [CFString: Any] {
        [
            kSecClass: securityClass,
            kSecAttrAccessible: keychainWriteAccessType,
            kSecAttrService: serviceKey,
            kSecAttrAccount: Keys.biometryMigratedAccountKey,
            kSecValueData: Data([1]) as AnyObject,
        ]
    }

    var serviceKey: String {
        "v2pwd\(seedProvider())"
    }

    var keychainWriteAccessType: Any {
        kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    }

    var securityClass: Any {
        kSecClassGenericPassword
    }

    func encryptedPasscodeAccountKey(slot: ABStorageSlot) -> String {
        accountKey(
            base: Keys.encryptedPasscodeAccountKey,
            slot: slot
        )
    }

    func wrapKeyAccountKey(slot: ABStorageSlot) -> String {
        accountKey(
            base: Keys.wrapKeyAccountKey,
            slot: slot
        )
    }

    func accountKey(
        base: String,
        slot: ABStorageSlot
    ) -> String {
        "\(base)_\(slot.rawValue)"
    }
}

private enum Keys {
    static let encryptedPasscodeAccountKey = "PasscodeEncrypted"
    static let wrapKeyAccountKey = "PasscodeWrapKey"
    static let biometryMigratedAccountKey = "PasscodeBiometryMigrated"
}

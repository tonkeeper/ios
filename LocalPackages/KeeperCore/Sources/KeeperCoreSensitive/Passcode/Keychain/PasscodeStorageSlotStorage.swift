import Foundation
import LocalAuthentication
import TKLogging

struct PasscodeStorageSlotStorage: ABSlotDataPresenceCheckingStorage {
    struct SetInput {
        let wrapKey: Data
        let encryptedPayload: Data
        let accessControl: SecAccessControl
    }

    enum WriteInput {
        case set(SetInput)
        case delete
    }

    let keychain: SecureStorageKeychain
    let slot: ABStorageSlot
    let keychainQuery: (PasscodeStorageKeychainQuery) -> [CFString: Any]
    let cleanup: () throws(PasscodeStorageFailure) -> Void

    func prepare() throws(PasscodeStorageFailure) {
        try cleanup()
    }

    func write(_ input: WriteInput) throws(PasscodeStorageFailure) {
        switch input {
        case let .set(input):
            try upsertWrapKey(
                with: input.wrapKey,
                accessControl: input.accessControl
            )
            try upsertEncryptedPasscode(with: input.encryptedPayload)
        case .delete:
            return
        }
    }

    func hasData() throws(PasscodeStorageFailure) -> Bool {
        let hasEncryptedPasscode = keychainItemExists(
            query: keychainQuery(
                .checkEncryptedPasscode(slot: slot)
            ) as CFDictionary
        )
        guard hasEncryptedPasscode else {
            return false
        }
        return wrapKeyExists()
    }

    func encryptedPasscodePayload() throws(PasscodeStorageFailure) -> Data {
        let query = keychainQuery(
            .getEncryptedPasscode(slot: slot)
        ) as CFDictionary
        var item: CFTypeRef?
        let status = keychain.copyMatching(query, result: &item)

        guard status != errSecItemNotFound else {
            throw .notFound
        }
        guard status == errSecSuccess else {
            throw .securityFailure(code: status)
        }
        guard let data = item as? Data else {
            throw .decodeFailure(message: "wrong encrypted payload type: \(type(of: item))")
        }
        return data
    }

    /// Probes the wrap key's biometric access control WITHOUT prompting the
    /// user (`interactionNotAllowed`). The data read forces the access control to
    /// be evaluated: a still-valid item reports `errSecInteractionNotAllowed`
    /// (→ `.accessible`). A `biometryCurrentSet` item whose enrolled set changed
    /// reports `errSecAuthFailed` (→ `.invalidated`) on the Simulator, but
    /// `errSecItemNotFound` (→ `.missing`) on a real device — so on device this
    /// returns `.missing`, indistinguishable from a truly absent item here. That
    /// ambiguity is resolved in `MnemonicAccess.biometryAccessProbe()` via the
    /// non-biometry `hasMnemonics()` tiebreaker.
    func probeBiometryAccess() -> BiometryAccessState {
        let context = LAContext()
        context.interactionNotAllowed = true
        let query = keychainQuery(
            .getWrapKey(
                context: context,
                slot: slot
            )
        ) as CFDictionary
        // kSecReturnData requires a result pointer; discard the value (a valid
        // item returns errSecInteractionNotAllowed without yielding any data).
        var item: CFTypeRef?
        let status = keychain.copyMatching(query, result: &item)
        let state: BiometryAccessState
        switch status {
        case errSecSuccess, errSecInteractionNotAllowed:
            state = .accessible
        case errSecAuthFailed:
            state = .invalidated
        case errSecItemNotFound:
            state = .missing
        default:
            Log.e("Wrap key biometry probe failed, error code: \(status)")
            state = .indeterminate
        }
        return state
    }

    func readWrapKey(context: LAContext) throws(PasscodeStorageFailure) -> Data {
        let query = keychainQuery(
            .getWrapKey(
                context: context,
                slot: slot
            )
        ) as CFDictionary
        var item: CFTypeRef?
        let status = keychain.copyMatching(query, result: &item)

        guard status != errSecItemNotFound else {
            throw .notFound
        }
        guard status == errSecSuccess else {
            throw .securityFailure(code: status)
        }
        guard let data = item as? Data else {
            throw .decodeFailure(message: "wrong wrap key type: \(type(of: item))")
        }
        return data
    }

    /// Always recreates (delete-then-add) the wrap key: SecItemUpdate can't
    /// reliably replace the access control of an auth-protected (possibly
    /// invalidated) item, and SecItemAdd on an existing item returns
    /// errSecDuplicateItem. SecItemDelete needs no authentication, so this also
    /// migrates a legacy biometryAny item to biometryCurrentSet.
    private func upsertWrapKey(
        with wrapKey: Data,
        accessControl: SecAccessControl
    ) throws(PasscodeStorageFailure) {
        let deleteStatus = keychain.delete(
            keychainQuery(
                .removeWrapKey(slot: slot)
            ) as CFDictionary
        )
        switch deleteStatus {
        case errSecSuccess, errSecItemNotFound:
            break
        default:
            Log.e("Wrap key overwrite failed to delete old item: error code \(deleteStatus)")
            throw .securityFailure(code: deleteStatus)
        }

        let addStatus = keychain.add(
            keychainQuery(
                .addWrapKey(
                    value: wrapKey,
                    accessControl: accessControl,
                    slot: slot
                )
            ) as CFDictionary,
            result: nil
        )
        guard addStatus == errSecSuccess else {
            Log.e("Wrap key save failed, error code: \(addStatus)")
            throw .securityFailure(code: addStatus)
        }
    }

    private func upsertEncryptedPasscode(
        with payload: Data
    ) throws(PasscodeStorageFailure) {
        let passcodeAddStatus = keychain.add(
            keychainQuery(
                .addEncryptedPasscode(
                    value: payload,
                    slot: slot
                )
            ) as CFDictionary,
            result: nil
        )
        switch passcodeAddStatus {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            return try overwriteEncryptedPasscode(with: payload)
        default:
            Log.e("Encrypted passcode save failed, error code: \(passcodeAddStatus)")
            throw .securityFailure(code: passcodeAddStatus)
        }
    }

    private func overwriteEncryptedPasscode(
        with payload: Data
    ) throws(PasscodeStorageFailure) {
        let status = keychain.update(
            keychainQuery(
                .updateEncryptedPasscode(slot: slot)
            ) as CFDictionary,
            attributes: [
                kSecValueData: payload as AnyObject,
            ] as CFDictionary
        )
        guard status == errSecSuccess else {
            Log.e("Encrypted passcode overwrite failed, error code: \(status)")
            throw .securityFailure(code: status)
        }
    }

    private func keychainItemExists(query: CFDictionary) -> Bool {
        let status = keychain.copyMatching(query, result: nil)
        switch status {
        case errSecSuccess:
            return true
        case errSecItemNotFound:
            return false
        default:
            Log.e("Keychain item check failed, error code: \(status)")
            return false
        }
    }

    private func wrapKeyExists() -> Bool {
        let context = LAContext()
        context.interactionNotAllowed = true
        let query = keychainQuery(
            .checkWrapKey(
                context: context,
                slot: slot
            )
        ) as CFDictionary
        let status = keychain.copyMatching(query, result: nil)
        switch status {
        case errSecSuccess, errSecInteractionNotAllowed, errSecAuthFailed:
            // errSecAuthFailed: a present wrap key whose access control can no
            // longer be satisfied (biometryCurrentSet invalidated). This is the
            // Simulator path — on a real device an invalidated item returns
            // errSecItemNotFound instead, so `hasData()` reports false there. The
            // launch-time biometry-disable decision does NOT rely on this, so the
            // device case is handled; recovery keys off `probeBiometryAccess` plus
            // the biometry-migrated marker (see `isBiometryItemMigrated`).
            return true
        case errSecItemNotFound:
            return false
        default:
            return false
        }
    }
}

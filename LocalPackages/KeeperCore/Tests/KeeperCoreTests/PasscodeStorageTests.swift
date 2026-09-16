import Foundation
@testable import KeeperCoreSensitive
import LocalAuthentication
import Security
import Testing

struct PasscodeStorageTests {
    @Test
    func setPasscodeCanReplaceExistingPasscode() throws {
        let seed = "passcode-storage-tests-\(UUID().uuidString)"
        let keychain = InMemorySecureStorageKeychain()
        let storage = makeStorage(seed: seed, keychain: keychain)

        try storage.setPasscode("old")
        #expect(try storage.getPasscode() == "old")

        try storage.setPasscode("new")

        #expect(try storage.getPasscode() == "new")
        #expect(storage.hasPasscode())
    }

    @Test
    func encryptedPayloadWriteFailureKeepsPreviousPasscodeReadable() throws {
        let seed = "passcode-storage-tests-\(UUID().uuidString)"
        let keychain = InMemorySecureStorageKeychain()
        let storage = makeStorage(seed: seed, keychain: keychain)
        let service = serviceKey(seed: seed)

        try storage.setPasscode("old")
        keychain.setAddFailure(
            service: service,
            account: "PasscodeEncrypted_b",
            status: errSecInteractionNotAllowed
        )

        do {
            try storage.setPasscode("new")
            Issue.record("Expected encrypted payload write failure")
        } catch let PasscodeStorageFailure.securityFailure(code) {
            #expect(code == errSecInteractionNotAllowed)
        } catch {
            Issue.record("Expected securityFailure, got \(error)")
        }

        #expect(try storage.getPasscode() == "old")
        #expect(storage.hasPasscode())
    }

    @Test
    func activeSlotUpdateFailureKeepsPreviousPasscodeReadable() throws {
        let seed = "passcode-storage-tests-\(UUID().uuidString)"
        let keychain = InMemorySecureStorageKeychain()
        let storage = makeStorage(seed: seed, keychain: keychain)
        let service = serviceKey(seed: seed)

        try storage.setPasscode("old")
        keychain.setUpdateFailure(
            service: service,
            account: "active_slot",
            status: errSecInteractionNotAllowed
        )

        do {
            try storage.setPasscode("new")
            Issue.record("Expected active slot update failure")
        } catch let PasscodeStorageFailure.securityFailure(code) {
            #expect(code == errSecInteractionNotAllowed)
        } catch {
            Issue.record("Expected securityFailure, got \(error)")
        }

        #expect(try storage.getPasscode() == "old")
        #expect(storage.hasPasscode())
        #expect(!keychain.containsItem(service: service, account: "PasscodeEncrypted_b"))
        #expect(!keychain.containsItem(service: service, account: "PasscodeWrapKey_b"))
    }

    @Test
    func getPasscodeTreatsMissingActiveSlotAsNotFound() throws {
        let seed = "passcode-storage-tests-\(UUID().uuidString)"
        let keychain = InMemorySecureStorageKeychain()
        let storage = makeStorage(seed: seed, keychain: keychain)
        let service = serviceKey(seed: seed)

        try storage.setPasscode("slot-b")
        try storage.setPasscode("slot-a")
        keychain.removeItem(service: service, account: "active_slot")

        #expect(!storage.hasPasscode())
        do {
            _ = try storage.getPasscode()
            Issue.record("Expected passcode not found")
        } catch PasscodeStorageFailure.notFound {
        } catch {
            Issue.record("Expected notFound, got \(error)")
        }
    }

    @Test
    func deletePasscodeCommitsEmptyActiveSlotAndCleansPreviousArtifacts() throws {
        let seed = "passcode-storage-tests-\(UUID().uuidString)"
        let keychain = InMemorySecureStorageKeychain()
        let storage = makeStorage(seed: seed, keychain: keychain)
        let service = serviceKey(seed: seed)

        try storage.setPasscode("slotted")

        try storage.deletePasscode()

        #expect(!storage.hasPasscode())
        do {
            _ = try storage.getPasscode()
            Issue.record("Expected passcode not found")
        } catch PasscodeStorageFailure.notFound {
        } catch {
            Issue.record("Expected notFound, got \(error)")
        }
        #expect(try activeSlotState(seed: seed, keychain: keychain) == .initialized(.b))
        #expect(keychain.containsItem(service: service, account: "active_slot"))
        for account in [
            "PasscodeEncrypted_a",
            "PasscodeWrapKey_a",
            "PasscodeEncrypted_b",
            "PasscodeWrapKey_b",
        ] {
            #expect(!keychain.containsItem(service: service, account: account))
        }
    }

    @Test
    func deletePasscodePreviousSlotCleanupFailureDoesNotThrow() throws {
        let seed = "passcode-storage-tests-\(UUID().uuidString)"
        let keychain = InMemorySecureStorageKeychain()
        let storage = makeStorage(seed: seed, keychain: keychain)
        let service = serviceKey(seed: seed)

        try storage.setPasscode("slotted")
        keychain.setDeleteFailure(
            service: service,
            account: "PasscodeEncrypted_a",
            status: errSecInteractionNotAllowed
        )

        try storage.deletePasscode()

        #expect(!storage.hasPasscode())
        #expect(try activeSlotState(seed: seed, keychain: keychain) == .initialized(.b))
        #expect(keychain.containsItem(service: service, account: "PasscodeEncrypted_a"))
    }

    @Test
    func deletePasscodeActivationFailureKeepsPreviousPasscodeReadable() throws {
        let seed = "passcode-storage-tests-\(UUID().uuidString)"
        let keychain = InMemorySecureStorageKeychain()
        let storage = makeStorage(seed: seed, keychain: keychain)
        let service = serviceKey(seed: seed)

        try storage.setPasscode("old")
        keychain.setUpdateFailure(
            service: service,
            account: "active_slot",
            status: errSecInteractionNotAllowed
        )

        do {
            try storage.deletePasscode()
            Issue.record("Expected active slot update failure")
        } catch let PasscodeStorageFailure.securityFailure(code) {
            #expect(code == errSecInteractionNotAllowed)
        } catch {
            Issue.record("Expected securityFailure, got \(error)")
        }

        keychain.setUpdateFailure(
            service: service,
            account: "active_slot",
            status: errSecSuccess
        )
        #expect(try storage.getPasscode() == "old")
        #expect(storage.hasPasscode())
        #expect(try activeSlotState(seed: seed, keychain: keychain) == .initialized(.a))
        #expect(!keychain.containsItem(service: service, account: "PasscodeEncrypted_b"))
        #expect(!keychain.containsItem(service: service, account: "PasscodeWrapKey_b"))
    }

    @Test
    func hasPasscodeChecksOnlyActiveSlotData() throws {
        let seed = "passcode-storage-tests-\(UUID().uuidString)"
        let keychain = InMemorySecureStorageKeychain()
        let storage = makeStorage(seed: seed, keychain: keychain)
        let service = serviceKey(seed: seed)

        try storage.deletePasscode()
        keychain.setItem(
            service: service,
            account: "PasscodeEncrypted_b",
            data: Data([1, 2, 3])
        )
        keychain.setItem(
            service: service,
            account: "PasscodeWrapKey_b",
            data: Data(repeating: 0, count: 32)
        )

        #expect(try activeSlotState(seed: seed, keychain: keychain) == .initialized(.a))
        #expect(!storage.hasPasscode())
    }

    @Test
    func getPasscodeSurfacesAuthFailedFromWrapKeyRead() throws {
        let seed = "passcode-storage-tests-\(UUID().uuidString)"
        let keychain = InMemorySecureStorageKeychain()
        let storage = makeStorage(seed: seed, keychain: keychain)
        let service = serviceKey(seed: seed)

        try storage.setPasscode("secret")
        keychain.setCopyFailure(
            service: service,
            account: "PasscodeWrapKey_a",
            status: errSecAuthFailed
        )

        do {
            _ = try storage.getPasscode()
            Issue.record("Expected wrap key read failure")
        } catch let PasscodeStorageFailure.securityFailure(code) {
            #expect(code == errSecAuthFailed)
        } catch {
            Issue.record("Expected securityFailure, got \(error)")
        }
    }

    @Test
    func hasPasscodeRemainsTrueWhenWrapKeyIsInvalidated() throws {
        let seed = "passcode-storage-tests-\(UUID().uuidString)"
        let keychain = InMemorySecureStorageKeychain()
        let storage = makeStorage(seed: seed, keychain: keychain)
        let service = serviceKey(seed: seed)

        try storage.setPasscode("secret")
        keychain.setCopyFailure(
            service: service,
            account: "PasscodeWrapKey_a",
            status: errSecAuthFailed
        )

        #expect(storage.hasPasscode())
    }

    @Test
    func writeRecreatesWrapKeyInsteadOfUpdatingProtectedItem() throws {
        let keychain = InMemorySecureStorageKeychain()
        let service = "slot-storage-tests-\(UUID().uuidString)"
        let storage = makeSlotStorage(service: service, slot: .a, keychain: keychain)

        keychain.setItem(
            service: service,
            account: "wrap_a",
            data: Data(repeating: 1, count: 32)
        )
        keychain.setUpdateFailure(
            service: service,
            account: "wrap_a",
            status: errSecAuthFailed
        )

        let newWrapKey = Data(repeating: 2, count: 32)
        try storage.write(
            .set(
                PasscodeStorageSlotStorage.SetInput(
                    wrapKey: newWrapKey,
                    encryptedPayload: Data([3, 4, 5]),
                    accessControl: makeAccessControl()
                )
            )
        )

        #expect(try storage.readWrapKey(context: LAContext()) == newWrapKey)
    }

    @Test
    func probeBiometryAccessReportsAccessibleWhenWrapKeyPresent() throws {
        let seed = "passcode-storage-tests-\(UUID().uuidString)"
        let keychain = InMemorySecureStorageKeychain()
        let storage = makeStorage(seed: seed, keychain: keychain)

        try storage.setPasscode("secret")

        #expect(storage.probeBiometryAccess() == .accessible)
    }

    @Test
    func probeBiometryAccessReportsInvalidatedWhenWrapKeyAuthFails() throws {
        let seed = "passcode-storage-tests-\(UUID().uuidString)"
        let keychain = InMemorySecureStorageKeychain()
        let storage = makeStorage(seed: seed, keychain: keychain)
        let service = serviceKey(seed: seed)

        try storage.setPasscode("secret")
        // A biometryCurrentSet item whose enrolled set changed reports
        // errSecAuthFailed even on a non-interactive read.
        keychain.setCopyFailure(
            service: service,
            account: "PasscodeWrapKey_a",
            status: errSecAuthFailed
        )

        #expect(storage.probeBiometryAccess() == .invalidated)
    }

    @Test
    func probeBiometryAccessReportsMissingWhenNoPasscode() throws {
        let seed = "passcode-storage-tests-\(UUID().uuidString)"
        let keychain = InMemorySecureStorageKeychain()
        let storage = makeStorage(seed: seed, keychain: keychain)

        try storage.deletePasscode()

        #expect(storage.probeBiometryAccess() == .missing)
    }

    @Test
    func probeBiometryAccessReportsIndeterminateOnUnexpectedError() throws {
        // An unexpected keychain status must not be misread as an invalidated
        // enrolled set, otherwise a transient error would raise a spurious
        // "biometry changed" alert. Be conservative and report indeterminate.
        let seed = "passcode-storage-tests-\(UUID().uuidString)"
        let keychain = InMemorySecureStorageKeychain()
        let storage = makeStorage(seed: seed, keychain: keychain)
        let service = serviceKey(seed: seed)

        try storage.setPasscode("secret")
        keychain.setCopyFailure(
            service: service,
            account: "PasscodeWrapKey_a",
            status: errSecParam
        )

        #expect(storage.probeBiometryAccess() == .indeterminate)
    }

    @Test
    func probeAndMarkerTellADiscardedCacheApartFromAnInvalidatedEnrolledSet() throws {
        // An enrollment change leaves the non-biometric marker untouched, so a
        // caller can treat a not-found wrap key as invalidated. A storage-version
        // rollback wipes the whole storage, marker included — the same not-found
        // read then means the cache is gone and the enrolled set never changed.
        let seed = "passcode-storage-tests-\(UUID().uuidString)"
        let keychain = InMemorySecureStorageKeychain()
        let storage = makeStorage(seed: seed, keychain: keychain)

        try storage.setPasscode("secret")
        #expect(storage.probeBiometryAccess() == .accessible)
        #expect(storage.isBiometryItemMigrated())

        try storage.deleteAllKnownStorageArtifacts()

        #expect(storage.probeBiometryAccess() == .missing)
        #expect(!storage.isBiometryItemMigrated())
    }

    @Test
    func isBiometryItemMigratedReflectsSetPasscode() throws {
        let seed = "passcode-storage-tests-\(UUID().uuidString)"
        let keychain = InMemorySecureStorageKeychain()
        let storage = makeStorage(seed: seed, keychain: keychain)

        // A legacy biometryAny item has no marker yet.
        #expect(!storage.isBiometryItemMigrated())

        // setPasscode recreates the wrap key with biometryCurrentSet and records
        // the migration, so the unlock path no longer re-encrypts on every input.
        try storage.setPasscode("secret")

        #expect(storage.isBiometryItemMigrated())
    }

    @Test
    func deleteAllKnownStorageArtifactsClearsBiometryMigrationMarker() throws {
        let seed = "passcode-storage-tests-\(UUID().uuidString)"
        let keychain = InMemorySecureStorageKeychain()
        let storage = makeStorage(seed: seed, keychain: keychain)

        try storage.setPasscode("secret")
        #expect(storage.isBiometryItemMigrated())

        try storage.deleteAllKnownStorageArtifacts()

        #expect(!storage.isBiometryItemMigrated())
    }

    @Test
    func deleteAllKnownStorageArtifactsSucceedsWhenNothingIsStored() throws {
        let seed = "passcode-storage-tests-\(UUID().uuidString)"
        let keychain = InMemorySecureStorageKeychain()
        let storage = makeStorage(seed: seed, keychain: keychain)

        try storage.deleteAllKnownStorageArtifacts()
    }

    @Test
    func deleteAllKnownStorageArtifactsToleratesBiometryMarkerRemovalFailure() throws {
        let seed = "passcode-storage-tests-\(UUID().uuidString)"
        let keychain = InMemorySecureStorageKeychain()
        let storage = makeStorage(seed: seed, keychain: keychain)

        try storage.setPasscode("secret")
        keychain.setDeleteFailure(
            service: serviceKey(seed: seed),
            account: "PasscodeBiometryMigrated",
            status: errSecInteractionNotAllowed
        )

        try storage.deleteAllKnownStorageArtifacts()

        #expect(!storage.hasPasscode())
    }

    @Test
    func deleteAllKnownStorageArtifactsRemovesSlottedArtifactsAndActivePointer() throws {
        let seed = "passcode-storage-tests-\(UUID().uuidString)"
        let keychain = InMemorySecureStorageKeychain()
        let storage = makeStorage(seed: seed, keychain: keychain)
        let service = serviceKey(seed: seed)

        try storage.setPasscode("slotted")
        keychain.setItem(
            service: service,
            account: "PasscodeEncrypted",
            data: Data([1, 2, 3])
        )
        keychain.setItem(
            service: service,
            account: "PasscodeWrapKey",
            data: Data(repeating: 0, count: 32)
        )

        try storage.deleteAllKnownStorageArtifacts()

        #expect(!storage.hasPasscode())
        for account in [
            "PasscodeEncrypted",
            "PasscodeWrapKey",
            "PasscodeEncrypted_a",
            "PasscodeWrapKey_a",
            "PasscodeEncrypted_b",
            "PasscodeWrapKey_b",
            "PasscodeBiometryMigrated",
            "active_slot",
        ] {
            #expect(!keychain.containsItem(service: service, account: account))
        }
    }
}

private extension PasscodeStorageTests {
    func makeStorage(
        seed: String,
        keychain: InMemorySecureStorageKeychain
    ) -> PasscodeStorage {
        PasscodeStorage(
            seedProvider: { seed },
            keychain: keychain
        )
    }

    func serviceKey(seed: String) -> String {
        "v2pwd\(seed)"
    }

    func makeAccessControl() throws -> SecAccessControl {
        try #require(
            SecAccessControlCreateWithFlags(
                kCFAllocatorDefault,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                [],
                nil
            )
        )
    }

    func makeSlotStorage(
        service: String,
        slot: ABStorageSlot,
        keychain: InMemorySecureStorageKeychain
    ) -> PasscodeStorageSlotStorage {
        PasscodeStorageSlotStorage(
            keychain: keychain,
            slot: slot,
            keychainQuery: { query in
                switch query {
                case let .checkEncryptedPasscode(slot):
                    return [
                        kSecAttrService: service,
                        kSecAttrAccount: "payload_\(slot.rawValue)",
                        kSecReturnAttributes: true,
                    ]
                case let .addEncryptedPasscode(value, slot):
                    return [
                        kSecAttrService: service,
                        kSecAttrAccount: "payload_\(slot.rawValue)",
                        kSecValueData: value,
                    ]
                case let .getEncryptedPasscode(slot):
                    return [
                        kSecAttrService: service,
                        kSecAttrAccount: "payload_\(slot.rawValue)",
                        kSecReturnData: true,
                    ]
                case let .updateEncryptedPasscode(slot),
                     let .removeEncryptedPasscode(slot):
                    return [
                        kSecAttrService: service,
                        kSecAttrAccount: "payload_\(slot.rawValue)",
                    ]
                case let .checkWrapKey(_, slot):
                    return [
                        kSecAttrService: service,
                        kSecAttrAccount: "wrap_\(slot.rawValue)",
                        kSecReturnAttributes: true,
                    ]
                case let .addWrapKey(value, accessControl, slot):
                    return [
                        kSecAttrService: service,
                        kSecAttrAccount: "wrap_\(slot.rawValue)",
                        kSecAttrAccessControl: accessControl,
                        kSecValueData: value,
                    ]
                case let .getWrapKey(_, slot):
                    return [
                        kSecAttrService: service,
                        kSecAttrAccount: "wrap_\(slot.rawValue)",
                        kSecReturnData: true,
                    ]
                case let .updateWrapKey(slot),
                     let .removeWrapKey(slot):
                    return [
                        kSecAttrService: service,
                        kSecAttrAccount: "wrap_\(slot.rawValue)",
                    ]
                case .removeEncryptedPasscodeLegacy:
                    return [
                        kSecAttrService: service,
                        kSecAttrAccount: "payload_legacy",
                    ]
                case .removeWrapKeyLegacy:
                    return [
                        kSecAttrService: service,
                        kSecAttrAccount: "wrap_legacy",
                    ]
                }
            },
            cleanup: {}
        )
    }

    func activeSlotState(
        seed: String,
        keychain: InMemorySecureStorageKeychain
    ) throws -> ABActiveSlotState {
        try ABActiveSlotKeychainStore(
            serviceKey: serviceKey(seed: seed),
            keychainWriteAccessType: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            keychain: keychain
        ).activeSlotState()
    }
}

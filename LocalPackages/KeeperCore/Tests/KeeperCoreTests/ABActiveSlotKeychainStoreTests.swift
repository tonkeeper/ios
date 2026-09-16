import Foundation
@testable import KeeperCoreSensitive
import Security
import Testing

struct ABActiveSlotKeychainStoreTests {
    @Test
    func missingActiveSlotReturnsUninitialized() throws {
        let store = makeStore()

        #expect(try store.activeSlotState() == .uninitialized)
    }

    @Test
    func setActiveSlotAddsAndUpdatesSlot() throws {
        let keychain = InMemorySecureStorageKeychain()
        let store = makeStore(keychain: keychain)

        try store.setActiveSlot(.b)
        #expect(try store.activeSlotState() == .initialized(.b))

        try store.setActiveSlot(.a)
        #expect(try store.activeSlotState() == .initialized(.a))
    }

    @Test
    func deleteActiveSlotRemovesStoredSlot() throws {
        let store = makeStore()

        try store.setActiveSlot(.b)
        try store.deleteActiveSlot()

        #expect(try store.activeSlotState() == .uninitialized)
    }

    @Test
    func malformedActiveSlotThrowsInvalidData() throws {
        let keychain = InMemorySecureStorageKeychain()
        let service = "ab-active-slot-tests-\(UUID().uuidString)"
        let store = makeStore(
            service: service,
            keychain: keychain
        )
        keychain.setItem(
            service: service,
            account: "active_slot",
            data: Data("malformed".utf8)
        )

        do {
            _ = try store.activeSlotState()
            Issue.record("Expected malformed active slot failure")
        } catch ABActiveSlotKeychainStore.Error.invalidData(_) {
        } catch {
            Issue.record("Expected invalidData, got \(error)")
        }
    }
}

private extension ABActiveSlotKeychainStoreTests {
    func makeStore(
        service: String = "ab-active-slot-tests-\(UUID().uuidString)",
        keychain: InMemorySecureStorageKeychain = InMemorySecureStorageKeychain()
    ) -> ABActiveSlotKeychainStore {
        ABActiveSlotKeychainStore(
            serviceKey: service,
            keychainWriteAccessType: kSecAttrAccessibleWhenUnlocked,
            keychain: keychain
        )
    }
}

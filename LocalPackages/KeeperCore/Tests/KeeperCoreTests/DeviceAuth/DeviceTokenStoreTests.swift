@testable import KeeperCore
import TKKeychain
import XCTest

/// `device_id` is resolved per analytics event, so the mirror is the reason the store is not a
/// keychain round trip each time — and why an unreadable keychain must not be cached.
final class DeviceTokenStoreTests: XCTestCase {
    func test_load_readsTheKeychainOnceAndThenServesTheMirror() {
        let vault = InMemoryKeychainVault()
        let store = DeviceTokenStore(keychainVault: vault)
        store.save(Self.record)
        let readsAfterSave = vault.readCount

        XCTAssertEqual(store.load(), Self.record)
        XCTAssertEqual(store.load(), Self.record)
        XCTAssertEqual(vault.readCount, readsAfterSave)
    }

    func test_load_primesAbsenceSoRepeatedMissesDoNotHitTheKeychain() {
        let vault = InMemoryKeychainVault()
        let store = DeviceTokenStore(keychainVault: vault)

        XCTAssertNil(store.load())
        let readsAfterFirstMiss = vault.readCount
        XCTAssertNil(store.load())

        XCTAssertEqual(vault.readCount, readsAfterFirstMiss)
    }

    func test_load_retriesAfterAnUnreadableKeychain() throws {
        let vault = InMemoryKeychainVault()
        let store = DeviceTokenStore(keychainVault: vault)
        try vault.set(JSONEncoder().encode(Self.record), query: Self.query)
        vault.readError = KeychainUnavailable.locked

        XCTAssertNil(store.load())
        // A read that could not answer says nothing about the stored record, so it must not be
        // remembered as "no record".
        vault.readError = nil
        XCTAssertEqual(store.load(), Self.record)
    }

    func test_save_updatesTheMirrorWithoutAReRead() {
        let vault = InMemoryKeychainVault()
        let store = DeviceTokenStore(keychainVault: vault)
        XCTAssertNil(store.load())

        store.save(Self.record)
        let readsAfterSave = vault.readCount

        XCTAssertEqual(store.load(), Self.record)
        XCTAssertEqual(vault.readCount, readsAfterSave)
    }

    func test_delete_dropsTheMirrorEvenWhenTheKeychainRefuses() {
        let vault = InMemoryKeychainVault()
        let store = DeviceTokenStore(keychainVault: vault)
        store.save(Self.record)
        vault.writeError = KeychainUnavailable.locked

        store.delete()
        let readsAfterDelete = vault.readCount

        // The record belongs to a certificate that is already regenerated, so it must not come
        // back regardless of what the keychain still holds.
        XCTAssertNil(store.load())
        XCTAssertEqual(vault.readCount, readsAfterDelete)
    }
}

private extension DeviceTokenStoreTests {
    enum KeychainUnavailable: Error {
        case locked
    }

    static let record = DeviceTokenStore.Record(deviceId: "device-1", refreshToken: "refresh-1")

    static var query: TKKeychainQuery {
        TKKeychainQuery(
            item: .genericPassword(service: "MultichainDeviceTokens", account: "device"),
            accessGroup: nil,
            biometry: .none,
            accessible: .whenUnlockedThisDeviceOnly
        )
    }
}

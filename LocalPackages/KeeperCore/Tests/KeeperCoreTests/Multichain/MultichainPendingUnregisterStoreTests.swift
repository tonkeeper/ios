import Foundation
@testable import KeeperCore
import XCTest

final class MultichainPendingUnregisterStoreTests: XCTestCase {
    func test_add_keepsIntentWhenKeychainWriteFails() {
        let vault = InMemoryKeychainVault()
        let defaults = makeFallbackDefaults()
        let store = MultichainPendingUnregisterStore(keychainVault: vault, fallbackDefaults: defaults)
        vault.writeError = KeychainWriteFailure()

        store.add(["a"])

        XCTAssertEqual(store.load(), ["a"])
        XCTAssertEqual(
            MultichainPendingUnregisterStore(keychainVault: vault, fallbackDefaults: defaults).load(),
            ["a"]
        )

        vault.writeError = nil
        store.add(["b"])

        // The next successful write repairs the stored copy, so a later launch sees both.
        XCTAssertEqual(
            MultichainPendingUnregisterStore(keychainVault: vault, fallbackDefaults: defaults).load(),
            ["a", "b"]
        )
    }

    func test_remove_doesNotResurrectIdsWhenKeychainWriteFails() {
        let vault = InMemoryKeychainVault()
        let defaults = makeFallbackDefaults()
        let store = MultichainPendingUnregisterStore(keychainVault: vault, fallbackDefaults: defaults)
        store.add(["a", "b"])
        vault.writeError = KeychainWriteFailure()

        store.remove(["a"])

        XCTAssertEqual(store.load(), ["b"])

        vault.writeError = nil
        store.remove(["b"])

        XCTAssertEqual(
            MultichainPendingUnregisterStore(keychainVault: vault, fallbackDefaults: defaults).load(),
            []
        )
    }

    func test_add_mergesWithTheStoredSnapshotAfterAReadFailure() {
        let vault = InMemoryKeychainVault()
        let defaults = makeFallbackDefaults()
        let store = MultichainPendingUnregisterStore(keychainVault: vault, fallbackDefaults: defaults)
        store.add(["a"])
        vault.readError = KeychainReadFailure()

        store.add(["b"])

        XCTAssertEqual(store.load(), ["b"])

        vault.readError = nil

        XCTAssertEqual(
            MultichainPendingUnregisterStore(keychainVault: vault, fallbackDefaults: defaults).load(),
            ["a", "b"]
        )
    }

    func test_remove_appliesToTheStoredSnapshotAfterAReadFailure() {
        let vault = InMemoryKeychainVault()
        let defaults = makeFallbackDefaults()
        let store = MultichainPendingUnregisterStore(keychainVault: vault, fallbackDefaults: defaults)
        store.add(["a", "b"])
        vault.readError = KeychainReadFailure()

        store.remove(["a"])
        vault.readError = nil

        XCTAssertEqual(
            MultichainPendingUnregisterStore(keychainVault: vault, fallbackDefaults: defaults).load(),
            ["b"]
        )
    }

    private func makeFallbackDefaults() -> UserDefaults {
        let suiteName = "MultichainPendingUnregisterStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }
}

private struct KeychainWriteFailure: Error {}
private struct KeychainReadFailure: Error {}

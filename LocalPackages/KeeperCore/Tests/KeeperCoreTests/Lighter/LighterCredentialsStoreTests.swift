import ChainKit
import Foundation
@testable import KeeperCore
import Security
import TKKeychain
import XCTest

final class LighterCredentialsStoreTests: XCTestCase {
    private let tradingKey = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0xFF, 0x00])

    func testTradingKeyReadsBackAsTheBytesThatWereStored() throws {
        let store = makeStore(vault: InMemoryKeychainVault())

        try store.saveL2PrivateKey(tradingKey)

        XCTAssertEqual(try store.loadL2PrivateKey(), tradingKey)
    }

    func testTradingKeyIsAbsentBeforeActivation() throws {
        XCTAssertNil(try makeStore(vault: InMemoryKeychainVault()).loadL2PrivateKey())
    }

    func testKeepingAKeyNeverReplacesTheRegisteredKey() throws {
        let vault = InMemoryKeychainVault()
        let store = makeStore(vault: vault)
        try store.saveL2PrivateKey(tradingKey)
        vault.readError = TKKeychainError.other(-1)

        try store.keepL2PrivateKey(Data(repeating: 0xAB, count: 40))

        vault.readError = nil
        XCTAssertEqual(try store.loadL2PrivateKey(), tradingKey)
    }

    func testConcurrentKeepsAcrossStoreInstancesPreserveOneKey() async throws {
        let vault = InMemoryKeychainVault()
        let keys = (0 ..< 16).map { Data(repeating: UInt8($0), count: 40) }
        try await withThrowingTaskGroup(of: Void.self) { group in
            for key in keys {
                group.addTask {
                    let store = LighterCredentialsStore(keychainVault: vault, walletId: "wallet-1", environment: "mainnet")
                    try store.keepL2PrivateKey(key)
                }
            }
            try await group.waitForAll()
        }
        let store = makeStore(vault: vault)
        let kept = try XCTUnwrap(store.loadL2PrivateKey())
        XCTAssertTrue(keys.contains(kept))
        for key in keys {
            try store.keepL2PrivateKey(key)
        }
        XCTAssertEqual(try store.loadL2PrivateKey(), kept)
    }

    func testTradingKeyIsPreparedBeforeAnAccountExists() async throws {
        let store = makeStore(vault: InMemoryKeychainVault())
        let wallet = try CryptoWallet.Companion.shared.fromMnemonic(
            mnemonic_: "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        )
        let otherWallet = try CryptoWallet.Companion.shared.fromMnemonic(
            mnemonic_: "legal winner thank year wave sausage worth useful legal winner thank yellow"
        )

        try await store.keepTradingKey(cryptoWallet: wallet)

        let key = try XCTUnwrap(store.loadL2PrivateKey())
        XCTAssertFalse(key.isEmpty)
        XCTAssertNotNil(PerpsKeyRegistration(apiKeyIndex: 3, publicKey: PerpsAccountService.tradingPublicKey(privateKey: key)))
        XCTAssertNil(try store.loadAccount())
        try await store.keepTradingKey(cryptoWallet: otherWallet)
        XCTAssertEqual(try store.loadL2PrivateKey(), key)
    }

    func testAFailedKeyWriteCanBeRetried() throws {
        let vault = InMemoryKeychainVault()
        let store = makeStore(vault: vault)
        vault.writeError = TKKeychainError.other(-1)
        XCTAssertThrowsError(try store.keepL2PrivateKey(tradingKey))
        XCTAssertNil(try store.loadL2PrivateKey())

        vault.writeError = nil
        try store.keepL2PrivateKey(tradingKey)

        XCTAssertEqual(try store.loadL2PrivateKey(), tradingKey)
    }

    func testAtomicInsertionOnlyIgnoresADuplicateItem() throws {
        let duplicate = TKKeychainVaultImplementation(keychain: InsertionKeychain(error: .other(errSecDuplicateItem)))
        XCTAssertNoThrow(try makeStore(vault: duplicate).keepL2PrivateKey(tradingKey))

        let denied = TKKeychainVaultImplementation(keychain: InsertionKeychain(error: .other(errSecInteractionNotAllowed)))
        XCTAssertThrowsError(try makeStore(vault: denied).keepL2PrivateKey(tradingKey))
    }

    func testAccountReadsBackWhatWasStored() throws {
        let store = makeStore(vault: InMemoryKeychainVault())

        try store.saveAccount(PerpsStoredAccount(accountIndex: 42, apiKeyIndex: 3))

        let stored = try XCTUnwrap(store.loadAccount())
        XCTAssertEqual(stored.accountIndex, 42)
        XCTAssertEqual(stored.apiKeyIndex, 3)
        XCTAssertEqual(stored.keyDerivationIndex, 42)
    }

    func testKeyDerivationIndexReadsBackWhatWasStored() throws {
        let store = makeStore(vault: InMemoryKeychainVault())

        try store.saveAccount(PerpsStoredAccount(accountIndex: 42, apiKeyIndex: 3, keyDerivationIndex: 0))

        XCTAssertEqual(try XCTUnwrap(store.loadAccount()).keyDerivationIndex, 0)
    }

    private func makeStore(vault: any TKKeychainVault) -> LighterCredentialsStore {
        LighterCredentialsStore(
            keychainVault: vault,
            walletId: "wallet-1",
            environment: "mainnet"
        )
    }
}

private struct InsertionKeychain: TKKeychain {
    let error: TKKeychainError

    func add(data _: Data, query _: TKKeychainQuery) throws {
        throw error
    }

    func exists(query _: TKKeychainQuery) throws -> Bool {
        false
    }

    func biometricAccessState(query _: TKKeychainQuery) -> TKKeychainBiometryAccess {
        .missing
    }

    func get(query _: TKKeychainQuery) throws -> Data? {
        XCTFail("keeping a key must not read before inserting")
        throw error
    }

    func update(query _: TKKeychainQuery, attributes _: TKKeychainAttributes) throws {
        XCTFail("keeping a key must not update an existing item")
        throw error
    }

    func delete(query _: TKKeychainQuery) throws {
        throw error
    }
}

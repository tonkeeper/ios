import Foundation
@testable import KeeperCore
import KeeperCoreSensitive
import TKTestSupport
import XCTest

final class MnemonicAccessUnlockTests: XCTestCase {
    func test_successfulOrdinaryUnlockPublishesAllMnemonics() async throws {
        var access = MnemonicAccess.inMemory(seed: "battery-unlock")
        let first = try migrationWallet(id: "first")
        let second = try migrationWallet(id: "second")
        try await access.saveMnemonic(migrationMnemonic, wallets: [first, second], passcode: "1234")
        let unlocks = MnemonicUnlocks()
        access.didUnlockMnemonics = { mnemonics in await unlocks.record(mnemonics) }

        let valid = await access.validatePasscode("1234")

        XCTAssertTrue(valid)
        try await unlocks.received.wait()
        let recorded = await unlocks.walletIds
        XCTAssertEqual(recorded, [Set(["first", "second"])])
    }

    func test_wrongPasscodeDoesNotPrepareMigrations() async throws {
        var access = MnemonicAccess.inMemory(seed: "battery-wrong-unlock")
        try await access.saveMnemonic(migrationMnemonic, wallet: migrationWallet(), passcode: "1234")
        let unlocks = MnemonicUnlocks()
        access.didUnlockMnemonics = { mnemonics in await unlocks.record(mnemonics) }

        let valid = await access.validatePasscode("0000")

        XCTAssertFalse(valid)
        let recorded = await unlocks.walletIds
        XCTAssertTrue(recorded.isEmpty)
    }

    func test_singleAndBatchReadsNotifyWithoutAnotherPasswordRequest() async throws {
        var access = MnemonicAccess.inMemory(seed: "battery-sign-unlock")
        let first = try migrationWallet(id: "first")
        let second = try migrationWallet(id: "second")
        try await access.saveMnemonic(migrationMnemonic, wallets: [first, second], passcode: "1234")
        let unlocks = MnemonicUnlocks(expectedCount: 2)
        access.didUnlockMnemonics = { mnemonics in await unlocks.record(mnemonics) }

        _ = try await access.getMnemonic(wallet: first, passcode: "1234")
        let returned = try await access.getMnemonics(wallets: [first], passcode: "1234")

        XCTAssertEqual(Set(returned.keys), Set(["first"]))
        try await unlocks.received.wait()
        let recorded = await unlocks.walletIds
        XCTAssertEqual(recorded, [Set(["first"]), Set(["first"])])
    }

    func test_unlockAndSigningReadsReturnWhileMigrationPreparationIsSuspended() async throws {
        var access = MnemonicAccess.inMemory(seed: "battery-unlock-does-not-wait")
        let wallet = try migrationWallet()
        try await access.saveMnemonic(migrationMnemonic, wallet: wallet, passcode: "1234")
        let hold = TestGate()
        let unlocks = MnemonicUnlocks(expectedCount: 3)
        access.didUnlockMnemonics = { mnemonics in
            await unlocks.record(mnemonics)
            try? await hold.wait()
        }

        let valid = await access.validatePasscode("1234")
        _ = try await access.getMnemonic(wallet: wallet, passcode: "1234")
        _ = try await access.getMnemonics(wallets: [wallet], passcode: "1234")

        XCTAssertTrue(valid)
        try await unlocks.received.wait()
        await hold.open()
    }
}

private actor MnemonicUnlocks {
    private(set) var walletIds = [Set<String>]()
    let received = TestGate()
    private let expectedCount: Int

    init(expectedCount: Int = 1) {
        self.expectedCount = expectedCount
    }

    func record(_ mnemonics: [CoreMnemonicIdentifier: CoreMnemonic]) async {
        walletIds.append(Set(mnemonics.keys))
        if walletIds.count == expectedCount { await received.open() }
    }
}

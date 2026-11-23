import Foundation
@testable import KeeperCore
import TKTestSupport
import XCTest

final class BatteryPaymentPreparationTests: XCTestCase {
    func test_oneUnlockWaitsForMigrationAndCanBeReusedByTheTransaction() async throws {
        let hold = TestGate()
        let session = BatteryPaymentTestSession(hold: hold)
        let preparation = BatteryPaymentPreparation(needsMigration: { _ in true }, migrate: { _, code in try await session.migrate(code) })
        let wallet = try migrationWallet()
        let task = Task { try await preparation.prepare(wallet: wallet, signer: .mnemonic(passcodeProvider: { await session.passcode() })) }
        try await session.started.wait()

        let before = await session.events
        XCTAssertEqual(before, ["pin", "migration-start"])
        await hold.open()
        let result = try await task.value
        let prepared = try XCTUnwrap(result)
        guard case let .mnemonic(provider) = prepared.signer else { return XCTFail("Expected mnemonic signing") }
        let first = await provider()
        let second = await provider()

        XCTAssertEqual(first, "1234")
        XCTAssertEqual(second, "1234")
        let after = await session.events
        XCTAssertEqual(after, ["pin", "migration-start", "migration-complete"])
    }

    func test_checkedWalletDoesNotRequestAnEarlyPasscode() async throws {
        let session = BatteryPaymentTestSession()
        let preparation = BatteryPaymentPreparation(needsMigration: { _ in false }, migrate: { _, code in try await session.migrate(code) })

        let prepared = try await preparation.prepare(wallet: migrationWallet(), signer: .mnemonic(passcodeProvider: { await session.passcode() }))

        XCTAssertNil(prepared)
        let events = await session.events
        XCTAssertTrue(events.isEmpty)
    }

    func testFundedMultichainAccountDoesNotDependOnLegacyMigration() async throws {
        let preparation = BatteryPaymentPreparation(
            needsMigration: { _ in true },
            migrate: { _, _ in XCTFail("The current account can already pay") },
            currentCharges: { _ in .available(18) }
        )

        let prepared = try await preparation.prepare(
            wallet: migrationWallet(),
            signer: .mnemonic(passcodeProvider: { XCTFail("Signing requests the ordinary PIN later"); return nil }),
            requiredCharges: 18
        )

        XCTAssertNil(prepared)
    }

    func testInsufficientCurrentBalanceStillWaitsForLegacyCredits() async throws {
        let session = BatteryPaymentTestSession()
        let preparation = BatteryPaymentPreparation(
            needsMigration: { _ in true },
            migrate: { _, code in try await session.migrate(code) },
            currentCharges: { _ in .available(17) }
        )

        let prepared = try await preparation.prepare(wallet: migrationWallet(), signer: .mnemonic(passcodeProvider: { await session.passcode() }), requiredCharges: 18)

        XCTAssertNotNil(prepared)
        let events = await session.events
        XCTAssertEqual(events, ["pin", "migration-start", "migration-complete"])
    }

    func test_failedMigrationDoesNotReturnASigningContext() async throws {
        let session = BatteryPaymentTestSession(fails: true)
        let preparation = BatteryPaymentPreparation(needsMigration: { _ in true }, migrate: { _, code in try await session.migrate(code) })
        do {
            _ = try await preparation.prepare(wallet: migrationWallet(), signer: .mnemonic(passcodeProvider: { await session.passcode() }))
            XCTFail("A failed migration must stop signing")
        } catch BatteryPaymentTestError.offline {}
        let events = await session.events
        XCTAssertEqual(events, ["pin", "migration-start"])
    }

    func test_cancelledPasscodeDoesNotStartMigration() async throws {
        let session = BatteryPaymentTestSession()
        let preparation = BatteryPaymentPreparation(needsMigration: { _ in true }, migrate: { _, code in try await session.migrate(code) })
        do {
            _ = try await preparation.prepare(wallet: migrationWallet(), signer: .mnemonic(passcodeProvider: { nil }))
            XCTFail("Expected cancellation")
        } catch is CancellationError {}
        let events = await session.events
        XCTAssertTrue(events.isEmpty)
    }
}

enum BatteryPaymentTestError: Error {
    case offline
}

actor BatteryPaymentTestSession {
    let started = TestGate()
    private let hold: TestGate?
    private let fails: Bool
    private(set) var migrated = false
    private(set) var events = [String]()

    init(hold: TestGate? = nil, fails: Bool = false) {
        self.hold = hold
        self.fails = fails
    }

    func passcode() -> String {
        events.append("pin")
        return "1234"
    }

    func migrate(_ passcode: String) async throws {
        XCTAssertEqual(passcode, "1234")
        events.append("migration-start")
        await started.open()
        try await hold?.wait()
        if fails { throw BatteryPaymentTestError.offline }
        migrated = true
        events.append("migration-complete")
    }

    func record(_ event: String) {
        events.append(event)
    }
}

import Foundation
@testable import KeeperCore
import KeeperCoreSensitive
import TKKeychain
import TKTestSupport
import XCTest

final class LegacyBatteryMigrationControllerTests: XCTestCase {
    func testCancelledPreviewReleasesTheFinishedWorkerBeforeTheNextRefresh() async throws {
        let entered = TestGate()
        let hold = TestGate()
        let network = try MigrationNetwork(balanceGate: hold, enteredBalance: entered)
        await network.setFailure(.balanceOffline)
        let controller = makeController(store: makeStore(), network: network, offerCacheLifetime: 0)
        let wallet = try JSONEncoder().encode(migrationWallet())
        let preview = Task { await controller.offersMigration(wallet: wallet) }
        try await entered.wait()
        preview.cancel()
        await hold.open()
        let cancelled = await preview.value
        XCTAssertFalse(cancelled)

        await network.setFailure(nil)
        let refreshed = await controller.offersMigration(wallet: wallet)

        XCTAssertTrue(refreshed)
        let counts = await network.counts
        XCTAssertEqual(counts.balances, 2)
    }

    func testInvalidatedPreviewRetriesTheBalanceReadInsteadOfReturningCancellationAsEmpty() async throws {
        let entered = TestGate()
        let hold = TestGate()
        let network = try MigrationNetwork(balanceGate: hold, enteredBalance: entered)
        let controller = makeController(store: makeStore(), network: network)
        let wallet = try JSONEncoder().encode(migrationWallet())
        let preview = Task { await controller.offersMigration(wallet: wallet) }
        try await entered.wait()

        try await controller.prepare(wallet: wallet, mnemonic: migrationMnemonic)
        await hold.open()
        let offered = await preview.value

        XCTAssertTrue(offered)
        let counts = await network.counts
        XCTAssertEqual(counts.balances, 2)
    }

    func testCancellationStopsWaitingWhileTheNetworkWorkerIsStillInFlight() async throws {
        let entered = TestGate()
        let hold = TestGate()
        let network = try MigrationNetwork()
        let controller = makeController(store: makeStore(), network: network, waitUntilIdle: { _ in
            await entered.open()
            await Task { try? await hold.wait() }.value
            return true
        })
        let prepared = try await controller.preparePayment(wallet: JSONEncoder().encode(migrationWallet()), mnemonic: migrationMnemonic)
        let authorization = try XCTUnwrap(prepared)
        let first = Task { try await controller.ensureMigrated(authorization) }
        try await entered.wait()

        first.cancel()
        do {
            try await first.value
            XCTFail("Cancellation must return before the network finishes")
        } catch is CancellationError {}
        let next = Task { try await controller.ensureMigrated(authorization) }
        next.cancel()
        do {
            try await next.value
            XCTFail("A cancelled retry must not wait for an orphaned worker")
        } catch is CancellationError {}

        await hold.open()
        try await controller.ensureMigrated(authorization)
        let counts = await network.counts
        XCTAssertEqual(counts.migrations, 1)
    }

    func testConcurrentPreviewRequestsShareAndCacheOneLegacyBalanceRead() async throws {
        let entered = TestGate()
        let hold = TestGate()
        let network = try MigrationNetwork(balanceGate: hold, enteredBalance: entered)
        let controller = makeController(store: makeStore(), network: network)
        let wallet = try JSONEncoder().encode(migrationWallet())
        async let first = controller.offersMigration(wallet: wallet)
        try await entered.wait()
        async let second = controller.offersMigration(wallet: wallet)
        await hold.open()

        let values = await[first, second, controller.offersMigration(wallet: wallet)]

        XCTAssertEqual(values, [true, true, true])
        let counts = await network.counts
        XCTAssertEqual(counts.balances, 1)
    }

    func testLegacyNetworkFailureDoesNotOverrideTheCurrentBatteryBalance() async throws {
        let network = try MigrationNetwork()
        await network.setFailure(.balanceOffline)
        let controller = makeController(store: makeStore(), network: network)

        let offered = try await controller.offersMigration(wallet: JSONEncoder().encode(migrationWallet()))

        XCTAssertFalse(offered)
    }

    func testMissingLegacyAuthorizationStillAllowsTheUserToUnlockForMigration() async throws {
        let network = try MigrationNetwork()
        await network.setFailure(.balance)
        let controller = makeController(store: makeStore(), network: network)

        let offered = try await controller.offersMigration(wallet: JSONEncoder().encode(migrationWallet()))

        XCTAssertTrue(offered)
    }

    func testPaymentRetriesAfterAFailedWorkerHasFinished() async throws {
        let network = try MigrationNetwork()
        await network.setFailure(.balanceOnce)
        let store = makeStore()
        let controller = makeController(store: store, network: network)
        let prepared = try await controller.preparePayment(wallet: JSONEncoder().encode(migrationWallet()), mnemonic: migrationMnemonic)
        let authorization = try XCTUnwrap(prepared)
        do {
            try await controller.ensureMigrated(authorization)
            XCTFail("Expected the first network read to fail")
        } catch MigrationFailure.offline {}

        try await controller.ensureMigrated(authorization)

        XCTAssertEqual(try store.load().completed.count, 1)
        let counts = await network.counts
        XCTAssertEqual(counts.migrations, 1)
    }

    func test_paymentWaitsForItsMigrationAndPersistsCompletion() async throws {
        let entered = TestGate()
        let hold = TestGate()
        let network = try MigrationNetwork(idleGate: hold, enteredIdle: entered)
        let store = makeStore()
        let controller = makeController(store: store, network: network)
        let preparedAuthorization = try await controller.preparePayment(wallet: JSONEncoder().encode(migrationWallet()), mnemonic: migrationMnemonic)

        let authorization = try XCTUnwrap(preparedAuthorization)
        let task = Task { try await controller.ensureMigrated(authorization) }
        try await entered.wait()

        XCTAssertEqual(try store.load().pending.count, 1)
        let before = await network.counts
        XCTAssertEqual(before.migrations, 0)
        await hold.open()
        try await task.value

        XCTAssertEqual(try store.load().completed.count, 1)
        XCTAssertTrue(try store.load().pending.isEmpty)
        let after = await network.counts
        XCTAssertEqual(after.migrations, 1)
    }

    func test_paymentRefreshesRejectedLegacyProofWithoutAnotherUnlock() async throws {
        let network = try MigrationNetwork()
        await network.setFailure(.balance)
        let store = makeStore()
        let controller = makeController(store: store, network: network, refreshAuthorization: { _, _ in await network.authorize() })
        let preparedAuthorization = try await controller.preparePayment(wallet: JSONEncoder().encode(migrationWallet()), mnemonic: migrationMnemonic)

        let authorization = try XCTUnwrap(preparedAuthorization)

        try await controller.ensureMigrated(authorization)

        let counts = await network.counts
        XCTAssertEqual(counts.authorizations, 1)
        XCTAssertEqual(counts.migrations, 1)
        XCTAssertEqual(try store.load().completed.count, 1)
    }

    func test_paymentReportsMigrationFailureRatherThanFinishingWithPendingWork() async throws {
        let network = try MigrationNetwork()
        await network.setFailure(.balanceOffline)
        let store = makeStore()
        let controller = makeController(store: store, network: network)
        let preparedAuthorization = try await controller.preparePayment(wallet: JSONEncoder().encode(migrationWallet()), mnemonic: migrationMnemonic)

        let authorization = try XCTUnwrap(preparedAuthorization)

        do {
            try await controller.ensureMigrated(authorization)
            XCTFail("A pending queue item is not a completed payment preparation")
        } catch MigrationFailure.offline {}

        XCTAssertEqual(try store.load().pending.count, 1)
        XCTAssertTrue(try store.load().completed.isEmpty)
    }

    func test_reservedLegacyChargesStopPaymentBeforeMigration() async throws {
        let network = try MigrationNetwork(balance: .init(balance: "1", reserved: "0.1"))
        let store = makeStore()
        let controller = makeController(store: store, network: network)
        let preparedAuthorization = try await controller.preparePayment(wallet: JSONEncoder().encode(migrationWallet()), mnemonic: migrationMnemonic)

        let authorization = try XCTUnwrap(preparedAuthorization)

        do {
            try await controller.ensureMigrated(authorization)
            XCTFail("Reserved charges cannot pay the transaction yet")
        } catch LegacyBatteryMigrationController.MigrationError.notReady {}

        let counts = await network.counts
        XCTAssertEqual(counts.migrations, 0)
        XCTAssertEqual(try store.load().pending.count, 1)
    }

    func test_paymentAndBackgroundQueueShareOneTransfer() async throws {
        let entered = TestGate()
        let hold = TestGate()
        let network = try MigrationNetwork(idleGate: hold, enteredIdle: entered)
        let store = makeStore()
        let controller = makeController(store: store, network: network)
        let background = await controller.prepare(mnemonics: ["local-wallet": migrationMnemonic])
        try await entered.wait()
        let preparedAuthorization = try await controller.preparePayment(wallet: JSONEncoder().encode(migrationWallet()), mnemonic: migrationMnemonic)

        let authorization = try XCTUnwrap(preparedAuthorization)
        async let payment: Void = controller.ensureMigrated(authorization)
        await hold.open()
        try await payment
        await background.value

        let counts = await network.counts
        XCTAssertEqual(counts.migrations, 1)
        XCTAssertEqual(try store.load().completed.count, 1)
    }

    func test_cancellingPaymentKeepsProofAndDoesNotTransferUntilRetry() async throws {
        let entered = TestGate()
        let hold = TestGate()
        let network = try MigrationNetwork(idleGate: hold, enteredIdle: entered)
        let store = makeStore()
        let controller = makeController(store: store, network: network)
        let preparedAuthorization = try await controller.preparePayment(wallet: JSONEncoder().encode(migrationWallet()), mnemonic: migrationMnemonic)

        let authorization = try XCTUnwrap(preparedAuthorization)
        let payment = Task { try await controller.ensureMigrated(authorization) }
        try await entered.wait()
        payment.cancel()
        do {
            try await payment.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {}
        let before = await network.counts
        XCTAssertEqual(before.migrations, 0)
        XCTAssertEqual(try store.load().pending.count, 1)

        await hold.open()
        try await controller.ensureMigrated(authorization)

        let after = await network.counts
        XCTAssertEqual(after.migrations, 1)
    }

    func test_previewOffersLegacyCreditsAndStopsOfferingAfterCompletion() async throws {
        let network = try MigrationNetwork()
        let store = makeStore()
        let controller = makeController(store: store, network: network)
        let wallet = try JSONEncoder().encode(migrationWallet())
        let offered = await controller.offersMigration(wallet: wallet)
        XCTAssertTrue(offered)
        let preparedAuthorization = try await controller.preparePayment(wallet: wallet, mnemonic: migrationMnemonic)

        let authorization = try XCTUnwrap(preparedAuthorization)
        try await controller.ensureMigrated(authorization)

        let offeredAfter = await controller.offersMigration(wallet: wallet)
        XCTAssertFalse(offeredAfter)
    }

    func test_enricherPreparesProofWithoutStartingTransferUntilWalletIsSaved() async throws {
        let network = try MigrationNetwork(wallet: migrationWallet(isMultichain: false))
        let store = makeStore()
        let controller = makeController(store: store, network: network)

        try await controller.prepare(wallet: JSONEncoder().encode(migrationWallet()), mnemonic: migrationMnemonic)

        XCTAssertEqual(try store.load().pending.count, 1)
        let before = await network.counts
        XCTAssertEqual(before.balances, 0)
        try try await network.setWallet(migrationWallet())
        await drain(controller)
        let after = await network.counts
        XCTAssertEqual(after.migrations, 1)
    }

    func test_existingMultichainWalletIsPreparedWithoutWaitingForNetwork() async throws {
        let gate = TestGate()
        let network = try MigrationNetwork(balanceGate: gate)
        let store = makeStore()
        let controller = makeController(store: store, network: network)

        await controller.prepare(mnemonics: ["local-wallet": migrationMnemonic])
        let run = await controller.resume()

        XCTAssertEqual(try store.load().pending.count, 1)
        await gate.open()
        await run.value

        let counts = await network.counts
        XCTAssertEqual(counts.migrations, 1)
        XCTAssertEqual(counts.refreshes, 1)
        XCTAssertEqual(try store.load().completed.count, 1)
        XCTAssertTrue(try store.load().pending.isEmpty)
    }

    func test_relaunchRetriesPersistedProofWithoutMnemonicOrPasscode() async throws {
        let network = try MigrationNetwork()
        await network.setFailure(.balanceOffline)
        let store = makeStore()
        let first = makeController(store: store, network: network)
        await first.prepare(mnemonics: ["local-wallet": migrationMnemonic])
        await drain(first)
        let proof = try XCTUnwrap(store.load().pending.values.first?.proof.signature)

        await network.setFailure(nil)
        let relaunched = makeController(store: store, network: network)
        await drain(relaunched)

        let signatures = await network.signatures
        XCTAssertEqual(signatures, [proof])
        XCTAssertTrue(try store.load().pending.isEmpty)
        XCTAssertEqual(try store.load().completed.count, 1)
    }

    func test_deviceSessionFailureRetriesAfterRelaunchWithoutLegacyProofRefresh() async throws {
        let network = try MigrationNetwork()
        await network.setFailure(.deviceSession)
        let store = makeStore()
        let controller = makeController(store: store, network: network)
        let run = await controller.prepare(mnemonics: ["local-wallet": migrationMnemonic])
        await run.value

        XCTAssertEqual(try store.load().pending.values.first?.requiresAuthorizationRefresh, false)
        await network.setFailure(nil)
        await drain(makeController(store: store, network: network))

        XCTAssertTrue(try store.load().pending.isEmpty)
        XCTAssertEqual(try store.load().completed.count, 1)
        let counts = await network.counts
        XCTAssertEqual(counts.authorizations, 0)
        XCTAssertEqual(counts.migrations, 2)
    }

    func test_zeroAndNegativeLegacyBalancesAreCheckedOnlyOnce() async throws {
        for amount in ["0", "-0.1"] {
            let network = try MigrationNetwork(balance: .init(balance: amount, reserved: "0"))
            let store = makeStore()
            let controller = makeController(store: store, network: network)
            await controller.prepare(mnemonics: ["local-wallet": migrationMnemonic])
            await drain(controller)
            await controller.prepare(mnemonics: ["local-wallet": migrationMnemonic])
            await drain(controller)

            let counts = await network.counts
            XCTAssertEqual(counts.balances, 1)
            XCTAssertEqual(counts.migrations, 0)
            XCTAssertEqual(try store.load().completed.count, 1)
        }
    }

    func test_overlappingUnlocksDoNotDuplicateTransfers() async throws {
        let gate = TestGate()
        let network = try MigrationNetwork(balanceGate: gate)
        let store = makeStore()
        let controller = makeController(store: store, network: network)
        async let first = controller.prepare(mnemonics: ["local-wallet": migrationMnemonic])
        async let second = controller.prepare(mnemonics: ["local-wallet": migrationMnemonic])
        _ = await(first, second)
        let run = await controller.resume()

        XCTAssertEqual(try store.load().pending.count, 1)
        await gate.open()
        await run.value

        let counts = await network.counts
        XCTAssertEqual(counts.migrations, 1)
        XCTAssertEqual(counts.balances, 1)
    }

    func test_proofMustBePersistedBeforeAnyTransfer() async throws {
        let vault = InMemoryKeychainVault()
        vault.writeError = MigrationFailure.offline
        let store = makeStore(vault: vault)
        let network = try MigrationNetwork()
        let controller = makeController(store: store, network: network)

        await controller.prepare(mnemonics: ["local-wallet": migrationMnemonic])
        await drain(controller)
        let before = await network.counts
        XCTAssertEqual(before.migrations, 0)
        XCTAssertEqual(before.balances, 0)

        vault.writeError = nil
        await controller.prepare(mnemonics: ["local-wallet": migrationMnemonic])
        await drain(controller)
        let after = await network.counts
        XCTAssertEqual(after.migrations, 1)
    }

    func test_removedWalletIsRecheckedAfterWaitingAndIsNotMigrated() async throws {
        let entered = TestGate()
        let hold = TestGate()
        let network = try MigrationNetwork(idleGate: hold, enteredIdle: entered)
        let store = makeStore()
        let controller = makeController(store: store, network: network)
        await controller.prepare(mnemonics: ["local-wallet": migrationMnemonic])
        let run = await controller.resume()
        try await entered.wait()

        try await network.setWallet(nil)
        await hold.open()
        await run.value

        let removedCounts = await network.counts
        XCTAssertEqual(removedCounts.migrations, 0)
        XCTAssertEqual(try store.load().pending.count, 1)

        try try await network.setWallet(migrationWallet(id: "reimported"))
        await drain(controller)
        let restoredCounts = await network.counts
        XCTAssertEqual(restoredCounts.migrations, 1)
    }

    func test_pendingRegistrationDoesNotDiscardPreparedProof() async throws {
        let network = try MigrationNetwork(wallet: migrationWallet(syncState: .pending))
        let store = makeStore()
        let controller = makeController(store: store, network: network)
        await controller.prepare(mnemonics: ["local-wallet": migrationMnemonic])
        await drain(controller)

        XCTAssertEqual(try store.load().pending.count, 1)
        let before = await network.counts
        XCTAssertEqual(before.migrations, 0)

        try try await network.setWallet(migrationWallet())
        await drain(controller)
        let after = await network.counts
        XCTAssertEqual(after.migrations, 1)
    }

    func test_reservedBalanceAndInvalidBalanceRemainPending() async throws {
        for balance in [
            BatteryBalance(balance: "0", reserved: "0.1"),
            .init(balance: "invalid", reserved: "0"),
            .init(balance: "1garbage", reserved: "0"),
            .init(balance: "1", reserved: "-0.1"),
            .init(balance: "NaN", reserved: "0"),
        ] {
            let network = try MigrationNetwork(balance: balance)
            let store = makeStore()
            let controller = makeController(store: store, network: network)
            await controller.prepare(mnemonics: ["local-wallet": migrationMnemonic])
            await drain(controller)

            XCTAssertEqual(try store.load().pending.count, 1)
            XCTAssertTrue(try store.load().completed.isEmpty)
            let counts = await network.counts
            XCTAssertEqual(counts.migrations, 0)
        }
    }

    func test_scientificNotationAndSignedDecimalBalancesAreAccepted() async throws {
        for amount in ["1e-7", "+.5", "1.", "+0", "-1E-7"] {
            let network = try MigrationNetwork(balance: .init(balance: amount, reserved: "+0e0"))
            let store = makeStore()
            let controller = makeController(store: store, network: network)

            let run = await controller.prepare(mnemonics: ["local-wallet": migrationMnemonic])
            await run.value

            XCTAssertTrue(try store.load().pending.isEmpty, amount)
            XCTAssertEqual(try store.load().completed.count, 1, amount)
            let counts = await network.counts
            XCTAssertEqual(counts.migrations, ["1e-7", "+.5", "1."].contains(amount) ? 1 : 0, amount)
        }
    }

    func test_unknownTransferOutcomeIsReconciledWithoutSendingTwice() async throws {
        let network = try MigrationNetwork()
        await network.setFailure(.lostReply)
        let store = makeStore()
        let controller = makeController(store: store, network: network)
        let run = await controller.prepare(mnemonics: ["local-wallet": migrationMnemonic])
        await run.value
        XCTAssertEqual(try store.load().pending.count, 1)

        await network.setFailure(nil)
        let relaunched = makeController(store: store, network: network)
        await drain(relaunched)

        let counts = await network.counts
        XCTAssertEqual(counts.migrations, 1)
        XCTAssertEqual(counts.refreshes, 1)
        XCTAssertEqual(try store.load().completed.count, 1)
    }

    func test_cancellationKeepsTheSignedProofForNextResume() async throws {
        let entered = TestGate()
        let hold = TestGate()
        let network = try MigrationNetwork(idleGate: hold, enteredIdle: entered)
        let store = makeStore()
        let controller = makeController(store: store, network: network)
        await controller.prepare(mnemonics: ["local-wallet": migrationMnemonic])
        let run = await controller.resume()
        try await entered.wait()

        run.cancel()
        await run.value

        XCTAssertEqual(try store.load().pending.count, 1)
        await hold.open()
        await drain(controller)
        let counts = await network.counts
        XCTAssertEqual(counts.migrations, 1)
    }

    func test_alreadyMigratedResponseIsTerminal() async throws {
        let network = try MigrationNetwork()
        await network.setFailure(.alreadyMigrated)
        let store = makeStore()
        let controller = makeController(store: store, network: network)
        await controller.prepare(mnemonics: ["local-wallet": migrationMnemonic])
        await drain(controller)
        await drain(controller)

        let counts = await network.counts
        XCTAssertEqual(counts.migrations, 1)
        XCTAssertEqual(try store.load().completed.count, 1)
        XCTAssertTrue(try store.load().pending.isEmpty)
    }

    func test_keychainReadFailureDoesNotForgetPendingWork() async throws {
        let vault = InMemoryKeychainVault()
        let store = makeStore(vault: vault)
        let migration = try XCTUnwrap(LegacyBatteryMigration(wallet: migrationWallet(), mnemonic: migrationMnemonic))
        var state = LegacyBatteryMigrationStore.State()
        state.pending[migration.id] = migration
        try store.save(state)
        vault.readError = MigrationFailure.offline
        let network = try MigrationNetwork()
        let controller = makeController(store: store, network: network)
        await drain(controller)

        vault.readError = nil
        await drain(controller)

        let counts = await network.counts
        XCTAssertEqual(counts.migrations, 1)
        XCTAssertTrue(try store.load().pending.isEmpty)
    }

    func test_persistedQueueContainsProofButNoMnemonicAndIsScopedToInstallation() throws {
        let vault = InMemoryKeychainVault()
        let store = makeStore(vault: vault)
        let migration = try XCTUnwrap(LegacyBatteryMigration(wallet: migrationWallet(), mnemonic: migrationMnemonic))
        var state = LegacyBatteryMigrationStore.State()
        state.pending[migration.id] = migration
        try store.save(state)

        let encoded = try String(decoding: JSONEncoder().encode(store.load()), as: UTF8.self)
        XCTAssertTrue(encoded.contains(migration.proof.signature))
        XCTAssertFalse(encoded.contains("abandon"))
        XCTAssertTrue(try LegacyBatteryMigrationStore(keychainVault: vault, namespace: "another-installation").load().pending.isEmpty)
    }

    func test_olderProofWithoutAuthorizationRefreshFlagStillDecodes() throws {
        let migration = try XCTUnwrap(LegacyBatteryMigration(wallet: migrationWallet(), mnemonic: migrationMnemonic))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(migration)) as? [String: Any])
        object.removeValue(forKey: "requiresAuthorizationRefresh")

        let decoded = try JSONDecoder().decode(LegacyBatteryMigration.self, from: JSONSerialization.data(withJSONObject: object))

        XCTAssertEqual(decoded.id, migration.id)
        XCTAssertEqual(decoded.proof.signature, migration.proof.signature)
        XCTAssertFalse(decoded.requiresAuthorizationRefresh)
    }

    func test_corruptQueueIsReplacedOnNextOrdinaryUnlock() async throws {
        let vault = InMemoryKeychainVault()
        let store = makeStore(vault: vault)
        try vault.set(Data("corrupt".utf8), query: TKKeychainQuery(
            item: .genericPassword(service: "LegacyBatteryMigration.v1", account: "test"),
            accessGroup: nil,
            biometry: .none,
            accessible: .whenUnlockedThisDeviceOnly
        ))
        let network = try MigrationNetwork()
        let controller = makeController(store: store, network: network)

        let run = await controller.prepare(mnemonics: ["local-wallet": migrationMnemonic])
        await run.value

        XCTAssertTrue(try store.load().pending.isEmpty)
        XCTAssertEqual(try store.load().completed.count, 1)
        let counts = await network.counts
        XCTAssertEqual(counts.migrations, 1)
    }

    func test_missingAuthorizationRefreshesInBackgroundAfterOrdinaryUnlock() async throws {
        let gate = TestGate()
        let network = try MigrationNetwork()
        await network.setFailure(.balance)
        let store = makeStore()
        let expectedPrivateKey = try migrationMnemonic.toKeyPair().privateKey.data
        let controller = makeController(
            store: store,
            network: network,
            authorizationAvailable: { _ in false },
            refreshAuthorization: { _, privateKey in
                XCTAssertEqual(privateKey, expectedPrivateKey)
                try await gate.wait()
                await network.authorize()
            }
        )

        await controller.prepare(mnemonics: ["local-wallet": migrationMnemonic])
        let run = await controller.resume()
        XCTAssertEqual(try store.load().pending.count, 1)
        await gate.open()
        await run.value

        let counts = await network.counts
        XCTAssertEqual(counts.authorizations, 1)
        XCTAssertEqual(counts.migrations, 1)
    }

    func test_rejectedAuthorizationIsRefreshedAtNextOrdinaryUnlock() async throws {
        let network = try MigrationNetwork()
        await network.setFailure(.balance)
        let store = makeStore()
        let controller = makeController(
            store: store,
            network: network,
            refreshAuthorization: { _, _ in await network.authorize() }
        )
        await controller.prepare(mnemonics: ["local-wallet": migrationMnemonic])
        await drain(controller)
        XCTAssertEqual(try store.load().pending.values.first?.requiresAuthorizationRefresh, true)
        let rejectedCounts = await network.counts
        await drain(controller)
        await drain(controller)
        let foregroundCounts = await network.counts
        XCTAssertEqual(foregroundCounts.balances, rejectedCounts.balances)

        await controller.prepare(mnemonics: ["local-wallet": migrationMnemonic])
        await drain(controller)

        let counts = await network.counts
        XCTAssertEqual(counts.authorizations, 1)
        XCTAssertEqual(counts.migrations, 1)
    }

    func test_successfulAuthorizationRefreshIsNotRepeatedWhileBalanceIsReserved() async throws {
        let network = try MigrationNetwork(balance: .init(balance: "1", reserved: "0.1"))
        await network.setFailure(.balance)
        let store = makeStore()
        let controller = makeController(
            store: store,
            network: network,
            refreshAuthorization: { _, _ in await network.authorize() }
        )
        let first = await controller.prepare(mnemonics: ["local-wallet": migrationMnemonic])
        await first.value
        let second = await controller.prepare(mnemonics: ["local-wallet": migrationMnemonic])
        await second.value
        let third = await controller.prepare(mnemonics: ["local-wallet": migrationMnemonic])
        await third.value

        XCTAssertEqual(try store.load().pending.values.first?.requiresAuthorizationRefresh, false)
        let counts = await network.counts
        XCTAssertEqual(counts.authorizations, 1)
        XCTAssertEqual(counts.migrations, 0)
    }

    func test_failedAuthorizationRefreshWaitsForAnotherUnlock() async throws {
        let network = try MigrationNetwork()
        let store = makeStore()
        let controller = makeController(
            store: store,
            network: network,
            authorizationAvailable: { _ in false },
            refreshAuthorization: { _, _ in throw MigrationFailure.offline }
        )
        let run = await controller.prepare(mnemonics: ["local-wallet": migrationMnemonic])
        await run.value
        await drain(controller)

        XCTAssertEqual(try store.load().pending.values.first?.requiresAuthorizationRefresh, true)
        let counts = await network.counts
        XCTAssertEqual(counts.balances, 0)
    }

    func test_walletDeletionCancelsAuthorizationRefresh() async throws {
        let entered = TestGate()
        let hold = TestGate()
        let network = try MigrationNetwork()
        let store = makeStore()
        let controller = makeController(
            store: store,
            network: network,
            authorizationAvailable: { _ in false },
            refreshAuthorization: { _, _ in
                await entered.open()
                try await hold.wait()
                await network.authorize()
            }
        )
        let run = await controller.prepare(mnemonics: ["local-wallet": migrationMnemonic])
        try await entered.wait()
        try await network.setWallet(nil)

        await controller.cancelAuthorization(walletId: "local-wallet")
        await run.value

        let counts = await network.counts
        XCTAssertEqual(counts.authorizations, 0)
        XCTAssertEqual(counts.migrations, 0)
        XCTAssertEqual(try store.load().pending.values.first?.requiresAuthorizationRefresh, true)
    }

    func test_reimportCanRefreshBeforeCancelledAuthorizationFinishes() async throws {
        let firstEntered = TestGate()
        let secondEntered = TestGate()
        let releaseFirst = TestGate()
        let attempts = AuthorizationAttempts()
        let network = try MigrationNetwork()
        let store = makeStore()
        let controller = makeController(
            store: store,
            network: network,
            authorizationAvailable: { _ in false },
            refreshAuthorization: { _, _ in
                if await attempts.next() == 1 {
                    await firstEntered.open()
                    // Model a request whose cancellation acknowledgement is delayed.
                    let response = Task { try await releaseFirst.wait() }
                    try await response.value
                    try Task.checkCancellation()
                } else {
                    await network.authorize()
                    await secondEntered.open()
                }
            }
        )
        let run = await controller.prepare(mnemonics: ["local-wallet": migrationMnemonic])
        try await firstEntered.wait()
        await controller.cancelAuthorization(walletId: "local-wallet")
        try try await network.setWallet(migrationWallet(id: "reimported"))

        await controller.prepare(mnemonics: ["reimported": migrationMnemonic])
        try await secondEntered.wait()
        await releaseFirst.open()
        await run.value

        let refreshAttempts = await attempts.count
        XCTAssertEqual(refreshAttempts, 2)
        XCTAssertTrue(try store.load().pending.isEmpty)
        XCTAssertEqual(try store.load().completed.count, 1)
    }

    func test_completionWriteFailureIsRecoveredWithoutAnotherSignatureOrTransfer() async throws {
        let entered = TestGate()
        let hold = TestGate()
        let vault = InMemoryKeychainVault()
        let store = makeStore(vault: vault)
        let network = try MigrationNetwork(refreshGate: hold, enteredRefresh: entered)
        let controller = makeController(store: store, network: network)
        await controller.prepare(mnemonics: ["local-wallet": migrationMnemonic])
        let run = await controller.resume()
        try await entered.wait()

        vault.writeError = MigrationFailure.offline
        await hold.open()
        await run.value
        XCTAssertEqual(try store.load().pending.count, 1)
        XCTAssertTrue(try store.load().completed.isEmpty)

        vault.writeError = nil
        let relaunched = makeController(store: store, network: network)
        await drain(relaunched)

        let counts = await network.counts
        XCTAssertEqual(counts.migrations, 1)
        XCTAssertEqual(try store.load().completed.count, 1)
        XCTAssertTrue(try store.load().pending.isEmpty)
    }

    func test_foregroundDuringAFailingAttemptRunsAnotherPassWithoutUnlock() async throws {
        let entered = TestGate()
        let hold = TestGate()
        let network = try MigrationNetwork(balanceGate: hold, enteredBalance: entered)
        await network.setFailure(.balanceOnce)
        let store = makeStore()
        let controller = makeController(store: store, network: network)
        let run = await controller.prepare(mnemonics: ["local-wallet": migrationMnemonic])
        try await entered.wait()

        _ = await controller.resume()
        await hold.open()
        await run.value

        let counts = await network.counts
        XCTAssertEqual(counts.migrations, 1)
        XCTAssertEqual(try store.load().completed.count, 1)
    }

    private func makeStore(vault: InMemoryKeychainVault = InMemoryKeychainVault()) -> LegacyBatteryMigrationStore {
        LegacyBatteryMigrationStore(keychainVault: vault, namespace: "test")
    }

    private func makeController(
        store: LegacyBatteryMigrationStore,
        network: MigrationNetwork,
        authorizationAvailable: @escaping @Sendable (Data) -> Bool = { _ in true },
        refreshAuthorization: @escaping @Sendable (Data, Data) async throws -> Void = { _, _ in },
        waitUntilIdle: (@Sendable (Data) async throws -> Bool)? = nil,
        offerCacheLifetime: TimeInterval = 10
    ) -> LegacyBatteryMigrationController {
        LegacyBatteryMigrationController(dependencies: .init(
            load: store.load,
            save: store.save,
            wallets: { await network.wallets() },
            balance: { data in try await network.loadBalance(data) },
            waitUntilIdle: waitUntilIdle ?? { data in try await network.waitUntilIdle(data) },
            migrate: { data, proof in try await network.migrate(data, proof: proof) },
            refreshBalance: { _ in await network.refresh() },
            authorizationAvailable: authorizationAvailable,
            refreshAuthorization: refreshAuthorization,
            offerCacheLifetime: offerCacheLifetime
        ))
    }

    private func drain(_ controller: LegacyBatteryMigrationController) async {
        let run = await controller.resume()
        await run.value
    }
}

private enum MigrationFailure: Error {
    case offline
}

private actor MigrationNetwork {
    enum Failure: Sendable {
        case balance
        case balanceOffline
        case deviceSession
        case lostReply
        case alreadyMigrated
        case balanceOnce
    }

    struct Counts: Sendable {
        var balances = 0
        var migrations = 0
        var refreshes = 0
        var authorizations = 0
    }

    private var walletData: Data?
    private var balance: BatteryBalance
    private let balanceGate: TestGate?
    private let enteredBalance: TestGate?
    private let idleGate: TestGate?
    private let enteredIdle: TestGate?
    private let refreshGate: TestGate?
    private let enteredRefresh: TestGate?
    private var failure: Failure?
    private(set) var counts = Counts()
    private(set) var signatures = [String]()

    init(
        wallet: Wallet? = nil,
        balance: BatteryBalance = .init(balance: "0.5", reserved: "0"),
        balanceGate: TestGate? = nil,
        enteredBalance: TestGate? = nil,
        idleGate: TestGate? = nil,
        enteredIdle: TestGate? = nil,
        refreshGate: TestGate? = nil,
        enteredRefresh: TestGate? = nil
    ) throws {
        walletData = try JSONEncoder().encode(wallet ?? migrationWallet())
        self.balance = balance
        self.balanceGate = balanceGate
        self.enteredBalance = enteredBalance
        self.idleGate = idleGate
        self.enteredIdle = enteredIdle
        self.refreshGate = refreshGate
        self.enteredRefresh = enteredRefresh
    }

    func setWallet(_ wallet: Wallet?) throws {
        walletData = try wallet.map { try JSONEncoder().encode($0) }
    }

    func setFailure(_ failure: Failure?) {
        self.failure = failure
    }

    func authorize() {
        failure = nil
        counts.authorizations += 1
    }

    func wallets() -> [Data] {
        walletData.map { [$0] } ?? []
    }

    func loadBalance(_: Data) async throws -> BatteryBalance {
        counts.balances += 1
        await enteredBalance?.open()
        try await balanceGate?.wait()
        try Task.checkCancellation()
        if failure == .balanceOnce {
            failure = nil
            throw MigrationFailure.offline
        }
        if failure == .balance { throw BatteryAuthorizationError.legacyProofUnavailable }
        if failure == .balanceOffline { throw MigrationFailure.offline }
        return balance
    }

    func waitUntilIdle(_: Data) async throws -> Bool {
        await enteredIdle?.open()
        try await idleGate?.wait()
        return true
    }

    func migrate(_ data: Data, proof: BatteryMigrationProof) throws {
        let destination = try JSONDecoder().decode(Wallet.self, from: data)
        XCTAssertEqual(destination.multichainWalletId, try migrationWallet().multichainWalletId)
        counts.migrations += 1
        signatures.append(proof.signature)
        if failure == .deviceSession { throw BatteryAuthorizationError.unavailable }
        if failure == .alreadyMigrated { throw BatteryAPI.ApiError.badStatus(status: 409, message: "already migrated") }
        balance = .empty
        if failure == .lostReply { throw MigrationFailure.offline }
    }

    func refresh() async {
        counts.refreshes += 1
        await enteredRefresh?.open()
        try? await refreshGate?.wait()
    }
}

private actor AuthorizationAttempts {
    private(set) var count = 0
    func next() -> Int {
        count += 1
        return count
    }
}

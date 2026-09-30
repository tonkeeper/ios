@testable import KeeperCore
import KeeperCoreSensitive
import TonSwift
import XCTest

final class MultichainWalletSyncControllerTests: XCTestCase {
    func test_syncPendingWallets_syncsPendingAndFailedWalletsAndMarksSynced() async {
        let syncedWallet = makeWallet(
            id: "synced",
            multichain: .multichain(makeState(walletId: "synced-state", syncState: .synced))
        )
        let pendingWallet = makeWallet(
            id: "pending",
            multichain: .multichain(makeState(walletId: "pending-state", syncState: .pending))
        )
        let testnetWallet = makeWallet(
            id: "testnet",
            network: .testnet,
            multichain: .multichain(makeState(walletId: "testnet-state", syncState: .pending))
        )
        let failedWallet = makeWallet(
            id: "failed",
            multichain: .multichain(makeState(walletId: "failed-state", syncState: .failed))
        )
        let emptyAddressesWallet = makeWallet(
            id: "empty-addresses",
            multichain: .multichain(
                makeState(
                    walletId: "empty-addresses-state",
                    addresses: [],
                    syncState: .pending
                )
            )
        )
        let mnemonicsSpy = MultichainSyncMnemonicsSpy(
            mnemonics: [
                pendingWallet.id: makeMnemonic(word: "abandon"),
                failedWallet.id: makeMnemonic(word: "ability"),
            ]
        )
        let syncSpy = MultichainWalletSyncSpy()
        let persistenceSpy = MultichainSyncPersistenceSpy()
        let controller = makeController(
            wallets: [
                syncedWallet,
                pendingWallet,
                testnetWallet,
                failedWallet,
                emptyAddressesWallet,
            ],
            mnemonicsSpy: mnemonicsSpy,
            syncSpy: syncSpy,
            persistenceSpy: persistenceSpy
        )

        XCTAssertTrue(controller.needsStartupSync)

        await controller.syncPendingWallets(passcode: "1234")

        XCTAssertEqual(
            mnemonicsSpy.requestedWalletIds,
            [[pendingWallet.id, failedWallet.id]]
        )
        XCTAssertEqual(syncSpy.syncedWalletIds, ["pending-state", "failed-state"])
        XCTAssertEqual(
            syncSpy.mnemonics,
            [
                makeMnemonicPhrase(word: "abandon"),
                makeMnemonicPhrase(word: "ability"),
            ]
        )
        XCTAssertEqual(persistenceSpy.savedWalletIds, [pendingWallet.id, failedWallet.id])
        XCTAssertEqual(
            persistenceSpy.savedMultichainWallets,
            [
                .multichain(makeState(walletId: "pending-state", syncState: .synced)),
                .multichain(makeState(walletId: "failed-state", syncState: .synced)),
            ]
        )
    }

    func test_syncPendingWallets_marksFailedWhenSyncFails() async {
        let wallet = makeWallet(
            id: "wallet",
            multichain: .multichain(makeState(walletId: "wallet-state", syncState: .pending))
        )
        let mnemonicsSpy = MultichainSyncMnemonicsSpy(
            mnemonics: [
                wallet.id: makeMnemonic(word: "abandon"),
            ]
        )
        let syncSpy = MultichainWalletSyncSpy()
        syncSpy.errorWalletIds = ["wallet-state"]
        let persistenceSpy = MultichainSyncPersistenceSpy()
        let controller = makeController(
            wallets: [wallet],
            mnemonicsSpy: mnemonicsSpy,
            syncSpy: syncSpy,
            persistenceSpy: persistenceSpy
        )

        await controller.syncPendingWallets(passcode: "1234")

        XCTAssertEqual(
            syncSpy.syncedWalletIds,
            Array(repeating: "wallet-state", count: MultichainRetry.defaultAttempts)
        )
        XCTAssertEqual(persistenceSpy.savedWalletIds, [wallet.id])
        XCTAssertEqual(
            persistenceSpy.savedMultichainWallets,
            [
                .multichain(makeState(walletId: "wallet-state", syncState: .failed)),
            ]
        )
    }

    func test_warmMissingAppKeys_warmsSyncedWalletsWithoutAppKey() async {
        let coldSynced = makeWallet(
            id: "cold-synced",
            multichain: .multichain(makeState(walletId: "cold-state", syncState: .synced))
        )
        let warmSynced = makeWallet(
            id: "warm-synced",
            multichain: .multichain(makeState(walletId: "warm-state", syncState: .synced))
        )
        let pending = makeWallet(
            id: "pending",
            multichain: .multichain(makeState(walletId: "pending-state", syncState: .pending))
        )
        let mnemonicsSpy = MultichainSyncMnemonicsSpy(
            mnemonics: [
                coldSynced.id: makeMnemonic(word: "abandon"),
                warmSynced.id: makeMnemonic(word: "ability"),
                pending.id: makeMnemonic(word: "able"),
            ]
        )
        let syncSpy = MultichainWalletSyncSpy()
        let persistenceSpy = MultichainSyncPersistenceSpy()
        let appKeySpy = MultichainAppKeySpy(missingWalletIds: ["cold-state"])
        let controller = makeController(
            wallets: [coldSynced, warmSynced, pending],
            mnemonicsSpy: mnemonicsSpy,
            syncSpy: syncSpy,
            persistenceSpy: persistenceSpy,
            appKeySpy: appKeySpy
        )

        let needsWarmBefore = await controller.needsStartupAppKeyWarm()
        XCTAssertTrue(needsWarmBefore)
        await controller.warmMissingAppKeys(passcode: "1234")

        XCTAssertEqual(appKeySpy.warmedWalletIds, ["cold-state"])
        XCTAssertEqual(
            appKeySpy.warmedMnemonics,
            [Array(repeating: "abandon", count: 12).joined(separator: " ")]
        )
        XCTAssertEqual(mnemonicsSpy.requestedWalletIds, [["cold-synced"]])
        XCTAssertEqual(syncSpy.syncedWalletIds, [])
        XCTAssertEqual(persistenceSpy.savedWalletIds, [])
        let needsWarmAfter = await controller.needsStartupAppKeyWarm()
        XCTAssertFalse(needsWarmAfter)
    }

    func test_warmMissingAppKeys_doesNothingWhenEverySyncedWalletIsWarm() async {
        let synced = makeWallet(
            id: "synced",
            multichain: .multichain(makeState(walletId: "synced-state", syncState: .synced))
        )
        let mnemonicsSpy = MultichainSyncMnemonicsSpy(
            mnemonics: [synced.id: makeMnemonic(word: "abandon")]
        )
        let appKeySpy = MultichainAppKeySpy()
        let controller = makeController(
            wallets: [synced],
            mnemonicsSpy: mnemonicsSpy,
            syncSpy: MultichainWalletSyncSpy(),
            persistenceSpy: MultichainSyncPersistenceSpy(),
            appKeySpy: appKeySpy
        )

        let needsWarm = await controller.needsStartupAppKeyWarm()
        XCTAssertFalse(needsWarm)
        await controller.warmMissingAppKeys(passcode: "1234")

        XCTAssertEqual(appKeySpy.warmedWalletIds, [])
        XCTAssertEqual(mnemonicsSpy.requestedWalletIds, [])
    }

    func test_syncPendingWallets_skipsNonRetryableWallets() async {
        let publicKey = makePublicKey(id: "signer")
        let wallets = [
            makeWallet(
                id: "synced",
                multichain: .multichain(makeState(walletId: "synced-state", syncState: .synced))
            ),
            makeWallet(id: "unavailable", multichain: .unavailable),
            makeWallet(
                id: "testnet",
                network: .testnet,
                multichain: .multichain(makeState(walletId: "testnet-state", syncState: .pending))
            ),
            makeWallet(
                id: "signer",
                kind: .Signer(publicKey, .v4R2),
                multichain: .multichain(makeState(walletId: "signer-state", syncState: .pending))
            ),
            makeWallet(
                id: "empty-addresses",
                multichain: .multichain(
                    makeState(
                        walletId: "empty-addresses-state",
                        addresses: [],
                        syncState: .failed
                    )
                )
            ),
        ]
        let mnemonicsSpy = MultichainSyncMnemonicsSpy(mnemonics: [:])
        let syncSpy = MultichainWalletSyncSpy()
        let persistenceSpy = MultichainSyncPersistenceSpy()
        let controller = makeController(
            wallets: wallets,
            mnemonicsSpy: mnemonicsSpy,
            syncSpy: syncSpy,
            persistenceSpy: persistenceSpy
        )

        XCTAssertFalse(controller.needsStartupSync)

        await controller.syncPendingWallets(passcode: "1234")

        XCTAssertEqual(mnemonicsSpy.requestedWalletIds, [])
        XCTAssertEqual(syncSpy.syncedWalletIds, [])
        XCTAssertEqual(persistenceSpy.savedWalletIds, [])
    }

    func test_reconcileBindings_marksUnknownWalletsPendingAndDetachesStaleBindings() async {
        let syncedWallet = makeWallet(
            id: "synced",
            multichain: .multichain(makeState(walletId: "synced-state", syncState: .synced))
        )
        let unknownWallet = makeWallet(
            id: "unknown",
            multichain: .multichain(makeState(walletId: "unknown-state", syncState: .synced))
        )
        let bindingsSpy = MultichainBindingsSpy()
        bindingsSpy.bindings = DeviceBindings(
            known: ["synced-state"],
            unknown: ["unknown-state"],
            // A wallet the client did send must never be detached, even if the backend lists it.
            extra: ["gone-state", "synced-state"]
        )
        let persistenceSpy = MultichainSyncPersistenceSpy()
        let controller = makeController(
            wallets: [syncedWallet, unknownWallet],
            mnemonicsSpy: MultichainSyncMnemonicsSpy(mnemonics: [:]),
            syncSpy: MultichainWalletSyncSpy(),
            persistenceSpy: persistenceSpy,
            bindingsSpy: bindingsSpy
        )

        await controller.reconcileBindings()

        XCTAssertEqual(
            bindingsSpy.requestedWalletIds.map { $0.sorted() },
            [["synced-state", "unknown-state"]]
        )
        XCTAssertEqual(persistenceSpy.savedWalletIds, [unknownWallet.id])
        XCTAssertEqual(
            persistenceSpy.savedMultichainWallets,
            [.multichain(makeState(walletId: "unknown-state", syncState: .pending))]
        )
        XCTAssertEqual(bindingsSpy.unregisteredWalletIds, [["gone-state"]])
    }

    func test_reconcileBindings_detachesLeftoverBindingsWhenNoWalletsRemain() async {
        let bindingsSpy = MultichainBindingsSpy()
        bindingsSpy.bindings = DeviceBindings(known: [], unknown: [], extra: ["gone-state"])
        let controller = makeController(
            wallets: [],
            mnemonicsSpy: MultichainSyncMnemonicsSpy(mnemonics: [:]),
            syncSpy: MultichainWalletSyncSpy(),
            persistenceSpy: MultichainSyncPersistenceSpy(),
            bindingsSpy: bindingsSpy
        )

        await controller.reconcileBindings()

        XCTAssertEqual(bindingsSpy.requestedWalletIds, [[]])
        XCTAssertEqual(bindingsSpy.unregisteredWalletIds, [["gone-state"]])
    }

    /// Dropping the stored multichain state — a storage-format bump — leaves every wallet looking
    /// unichain until enrichment re-derives it. Detaching on that empty set would unbind the whole
    /// device, so the pass reports itself unfinished and waits for the next trigger instead.
    func test_reconcileBindings_skipsDetachWhileAWalletAwaitsEnrichment() async {
        let bindingsSpy = MultichainBindingsSpy()
        bindingsSpy.bindings = DeviceBindings(known: [], unknown: [], extra: ["live-state"])
        let controller = makeController(
            wallets: [makeWallet(id: "wallet")],
            mnemonicsSpy: MultichainSyncMnemonicsSpy(mnemonics: [:]),
            syncSpy: MultichainWalletSyncSpy(),
            persistenceSpy: MultichainSyncPersistenceSpy(),
            bindingsSpy: bindingsSpy
        )

        let didReconcile = await controller.reconcileBindings()

        XCTAssertFalse(didReconcile)
        XCTAssertEqual(bindingsSpy.requestedWalletIds, [])
        XCTAssertEqual(bindingsSpy.unregisteredWalletIds, [])
    }

    /// Enrichment can stop half way — one wallet gets its state, the next fails on its mnemonic.
    /// The local set is no longer empty then, but the wallet left behind still has no id to send,
    /// so its binding reads as stale. Demoting what the device does not know stays safe.
    func test_reconcileBindings_skipsDetachWhileAnotherWalletAwaitsEnrichment() async {
        let enrichedWallet = makeWallet(
            id: "enriched",
            multichain: .multichain(makeState(walletId: "enriched-state", syncState: .synced))
        )
        let bindingsSpy = MultichainBindingsSpy()
        bindingsSpy.bindings = DeviceBindings(
            known: [],
            unknown: ["enriched-state"],
            // The binding of the wallet that has not been enriched yet, indistinguishable here from
            // one left by a wallet that is gone.
            extra: ["awaiting-state"]
        )
        let persistenceSpy = MultichainSyncPersistenceSpy()
        let controller = makeController(
            wallets: [enrichedWallet, makeWallet(id: "awaiting")],
            mnemonicsSpy: MultichainSyncMnemonicsSpy(mnemonics: [:]),
            syncSpy: MultichainWalletSyncSpy(),
            persistenceSpy: persistenceSpy,
            bindingsSpy: bindingsSpy
        )

        let didReconcile = await controller.reconcileBindings()

        XCTAssertFalse(didReconcile)
        XCTAssertEqual(bindingsSpy.requestedWalletIds, [["enriched-state"]])
        XCTAssertEqual(persistenceSpy.savedWalletIds, [enrichedWallet.id])
        XCTAssertEqual(bindingsSpy.unregisteredWalletIds, [])
    }

    /// A wallet enrichment has already classified never contributes a walletId, so it must not
    /// block the detach for good.
    func test_reconcileBindings_detachesWhenRemainingWalletsAreUnavailable() async {
        let bindingsSpy = MultichainBindingsSpy()
        bindingsSpy.bindings = DeviceBindings(known: [], unknown: [], extra: ["gone-state"])
        let controller = makeController(
            wallets: [makeWallet(id: "wallet", multichain: .unavailable)],
            mnemonicsSpy: MultichainSyncMnemonicsSpy(mnemonics: [:]),
            syncSpy: MultichainWalletSyncSpy(),
            persistenceSpy: MultichainSyncPersistenceSpy(),
            bindingsSpy: bindingsSpy
        )

        let didReconcile = await controller.reconcileBindings()

        XCTAssertTrue(didReconcile)
        XCTAssertEqual(bindingsSpy.requestedWalletIds, [[]])
        XCTAssertEqual(bindingsSpy.unregisteredWalletIds, [["gone-state"]])
    }

    func test_reconcileBindings_skipsEmptyRequestWhenDeviceIsUnknown() async {
        let bindingsSpy = MultichainBindingsSpy()
        bindingsSpy.isDeviceKnown = false
        let controller = makeController(
            wallets: [],
            mnemonicsSpy: MultichainSyncMnemonicsSpy(mnemonics: [:]),
            syncSpy: MultichainWalletSyncSpy(),
            persistenceSpy: MultichainSyncPersistenceSpy(),
            bindingsSpy: bindingsSpy
        )

        await controller.reconcileBindings()

        XCTAssertEqual(bindingsSpy.requestedWalletIds, [])
    }

    func test_reconcileBindings_keepsStateWhenRequestFails() async {
        let wallet = makeWallet(
            id: "wallet",
            multichain: .multichain(makeState(walletId: "wallet-state", syncState: .synced))
        )
        let bindingsSpy = MultichainBindingsSpy()
        bindingsSpy.error = .connectionError
        let persistenceSpy = MultichainSyncPersistenceSpy()
        let controller = makeController(
            wallets: [wallet],
            mnemonicsSpy: MultichainSyncMnemonicsSpy(mnemonics: [:]),
            syncSpy: MultichainWalletSyncSpy(),
            persistenceSpy: persistenceSpy,
            bindingsSpy: bindingsSpy
        )

        await controller.reconcileBindings()

        XCTAssertEqual(persistenceSpy.savedWalletIds, [])
        XCTAssertEqual(bindingsSpy.unregisteredWalletIds, [])
    }

    func test_reconcileBindings_waitsForAnInFlightSync() async {
        let wallet = makeWallet(
            id: "pending",
            multichain: .multichain(makeState(walletId: "pending-state", syncState: .pending))
        )
        let syncSpy = MultichainWalletSyncSpy()
        syncSpy.blockGate = MultichainSyncGate()
        let bindingsSpy = MultichainBindingsSpy()
        let controller = makeController(
            wallets: [wallet],
            mnemonicsSpy: MultichainSyncMnemonicsSpy(mnemonics: [wallet.id: makeMnemonic(word: "abandon")]),
            syncSpy: syncSpy,
            persistenceSpy: MultichainSyncPersistenceSpy(),
            bindingsSpy: bindingsSpy
        )

        let sync = Task { await controller.syncPendingWallets(passcode: "1234") }
        await syncSpy.didStartSync.wait()
        let reconcile = Task { await controller.reconcileBindings() }
        // Nothing holds the reconcile back except the gate: every dependency it touches returns
        // immediately, so a non-serialized one would already have read the bindings by now.
        for _ in 0 ..< 64 {
            await Task.yield()
        }
        XCTAssertEqual(bindingsSpy.requestedWalletIds, [], "reconcile read bindings mid-sync")

        syncSpy.blockGate?.open()
        await sync.value
        await reconcile.value

        XCTAssertEqual(bindingsSpy.requestedWalletIds, [["pending-state"]])
    }

    func test_reconcileBindings_doesNotRunWhenCancelledWhileWaitingForSync() async {
        let wallet = makeWallet(
            id: "pending",
            multichain: .multichain(makeState(walletId: "pending-state", syncState: .pending))
        )
        let syncSpy = MultichainWalletSyncSpy()
        syncSpy.blockGate = MultichainSyncGate()
        let bindingsSpy = MultichainBindingsSpy()
        let controller = makeController(
            wallets: [wallet],
            mnemonicsSpy: MultichainSyncMnemonicsSpy(mnemonics: [wallet.id: makeMnemonic(word: "abandon")]),
            syncSpy: syncSpy,
            persistenceSpy: MultichainSyncPersistenceSpy(),
            bindingsSpy: bindingsSpy
        )

        let sync = Task { await controller.syncPendingWallets(passcode: "1234") }
        await syncSpy.didStartSync.wait()
        let didFinishReconcile = expectation(description: "Cancelled reconcile finished")
        let reconcile = Task {
            await controller.reconcileBindings()
            didFinishReconcile.fulfill()
        }
        // Nothing holds the reconcile back except the gate, so by now it is parked there.
        for _ in 0 ..< 64 {
            await Task.yield()
        }
        reconcile.cancel()
        await fulfillment(of: [didFinishReconcile], timeout: 1)
        await reconcile.value

        syncSpy.blockGate?.open()
        await sync.value

        XCTAssertEqual(bindingsSpy.requestedWalletIds, [])
    }

    // MARK: - Retrying a dropped connection

    func test_syncPendingWallets_registersAfterADroppedConnection() async {
        let wallet = makeWallet(
            id: "pending",
            multichain: .multichain(makeState(walletId: "pending-state", syncState: .pending))
        )
        let syncSpy = MultichainWalletSyncSpy()
        syncSpy.transientFailuresByWalletId = ["pending-state": 1]
        let persistenceSpy = MultichainSyncPersistenceSpy()
        let controller = makeController(
            wallets: [wallet],
            mnemonicsSpy: MultichainSyncMnemonicsSpy(mnemonics: [wallet.id: makeMnemonic(word: "abandon")]),
            syncSpy: syncSpy,
            persistenceSpy: persistenceSpy
        )

        await controller.syncPendingWallets(passcode: "1234")

        XCTAssertEqual(syncSpy.syncedWalletIds, ["pending-state", "pending-state"])
        guard case let .multichain(saved)? = persistenceSpy.savedMultichainWallets.first else {
            return XCTFail("expected a multichain state to be saved")
        }
        XCTAssertEqual(saved.syncState, .synced)
    }

    /// A proof the backend rejected is rejected again the same way, so it is not worth a pass.
    func test_syncPendingWallets_doesNotRepeatARejectedRegister() async {
        let wallet = makeWallet(
            id: "pending",
            multichain: .multichain(makeState(walletId: "pending-state", syncState: .pending))
        )
        let syncSpy = MultichainWalletSyncSpy()
        syncSpy.errorWalletIds = ["pending-state"]
        syncSpy.syncError = .apiError(message: "wallet proof rejected")
        let persistenceSpy = MultichainSyncPersistenceSpy()
        let controller = makeController(
            wallets: [wallet],
            mnemonicsSpy: MultichainSyncMnemonicsSpy(mnemonics: [wallet.id: makeMnemonic(word: "abandon")]),
            syncSpy: syncSpy,
            persistenceSpy: persistenceSpy
        )

        await controller.syncPendingWallets(passcode: "1234")

        XCTAssertEqual(syncSpy.syncedWalletIds, ["pending-state"])
        guard case let .multichain(saved)? = persistenceSpy.savedMultichainWallets.first else {
            return XCTFail("expected a multichain state to be saved")
        }
        XCTAssertEqual(saved.syncState, .failed)
    }

    func test_reconcileBindings_readsTheBindingsAfterADroppedConnection() async {
        let wallet = makeWallet(
            id: "synced",
            multichain: .multichain(makeState(walletId: "synced-state", syncState: .synced))
        )
        let bindingsSpy = MultichainBindingsSpy()
        bindingsSpy.transientFailures = 1
        bindingsSpy.bindings = DeviceBindings(known: ["synced-state"], unknown: [], extra: [])
        let controller = makeController(
            wallets: [wallet],
            mnemonicsSpy: MultichainSyncMnemonicsSpy(mnemonics: [:]),
            syncSpy: MultichainWalletSyncSpy(),
            persistenceSpy: MultichainSyncPersistenceSpy(),
            bindingsSpy: bindingsSpy
        )

        let didReconcile = await controller.reconcileBindings()

        XCTAssertTrue(didReconcile)
        XCTAssertEqual(bindingsSpy.requestedWalletIds.count, 2)
    }

    /// The caller owns the retry trigger — a launch that never reached the backend has to be
    /// repeated rather than remembered as done.
    func test_reconcileBindings_reportsFailureWhenTheRequestKeepsFailing() async {
        let wallet = makeWallet(
            id: "synced",
            multichain: .multichain(makeState(walletId: "synced-state", syncState: .synced))
        )
        let bindingsSpy = MultichainBindingsSpy()
        bindingsSpy.error = .connectionError
        let controller = makeController(
            wallets: [wallet],
            mnemonicsSpy: MultichainSyncMnemonicsSpy(mnemonics: [:]),
            syncSpy: MultichainWalletSyncSpy(),
            persistenceSpy: MultichainSyncPersistenceSpy(),
            bindingsSpy: bindingsSpy
        )

        let didReconcile = await controller.reconcileBindings()

        XCTAssertFalse(didReconcile)
        XCTAssertEqual(bindingsSpy.requestedWalletIds.count, MultichainRetry.defaultAttempts)
    }

    func test_reconcileBindings_doesNotRepeatARejectedRequest() async {
        let wallet = makeWallet(
            id: "synced",
            multichain: .multichain(makeState(walletId: "synced-state", syncState: .synced))
        )
        let bindingsSpy = MultichainBindingsSpy()
        bindingsSpy.error = .apiError(message: "bad request")
        let controller = makeController(
            wallets: [wallet],
            mnemonicsSpy: MultichainSyncMnemonicsSpy(mnemonics: [:]),
            syncSpy: MultichainWalletSyncSpy(),
            persistenceSpy: MultichainSyncPersistenceSpy(),
            bindingsSpy: bindingsSpy
        )

        let didReconcile = await controller.reconcileBindings()

        XCTAssertFalse(didReconcile)
        XCTAssertEqual(bindingsSpy.requestedWalletIds.count, 1)
    }

    // MARK: - Writing back state that changed during the call

    func test_syncPendingWallets_keepsAddressesWrittenWhileTheSyncWasInFlight() async {
        let enrichedAddresses = [
            MultichainWalletAddress(chain: .eth, address: "0xpending-state"),
            MultichainWalletAddress(chain: .tron, address: "Tpending-state"),
        ]
        let wallet = makeWallet(
            id: "pending",
            multichain: .multichain(makeState(walletId: "pending-state", syncState: .pending))
        )
        let store = MutableWalletsBox(wallets: [wallet])
        let syncSpy = MultichainWalletSyncSpy()
        syncSpy.blockGate = MultichainSyncGate()
        let persistenceSpy = MultichainSyncPersistenceSpy()
        let controller = makeController(
            wallets: [],
            mnemonicsSpy: MultichainSyncMnemonicsSpy(mnemonics: [wallet.id: makeMnemonic(word: "abandon")]),
            syncSpy: syncSpy,
            persistenceSpy: persistenceSpy,
            getWalletsProvider: { store.wallets }
        )

        let sync = Task { await controller.syncPendingWallets(passcode: "1234") }
        await syncSpy.didStartSync.wait()
        // The addresses enricher is not behind the gate, so it can land mid-sync.
        store.wallets = [
            makeWallet(
                id: wallet.id,
                multichain: .multichain(
                    makeState(
                        walletId: "pending-state",
                        addresses: enrichedAddresses,
                        syncState: .pending
                    )
                )
            ),
        ]
        syncSpy.blockGate?.open()
        await sync.value

        XCTAssertEqual(persistenceSpy.savedWalletIds, [wallet.id])
        guard case let .multichain(saved)? = persistenceSpy.savedMultichainWallets.first else {
            return XCTFail("expected a multichain state to be saved")
        }
        XCTAssertEqual(saved.addresses, enrichedAddresses)
        XCTAssertEqual(saved.syncState, .synced)
    }

    func test_syncPendingWallets_doesNotWriteAWalletThatWasDeletedDuringTheSync() async {
        let wallet = makeWallet(
            id: "pending",
            multichain: .multichain(makeState(walletId: "pending-state", syncState: .pending))
        )
        let store = MutableWalletsBox(wallets: [wallet])
        let syncSpy = MultichainWalletSyncSpy()
        syncSpy.blockGate = MultichainSyncGate()
        let persistenceSpy = MultichainSyncPersistenceSpy()
        let controller = makeController(
            wallets: [],
            mnemonicsSpy: MultichainSyncMnemonicsSpy(mnemonics: [wallet.id: makeMnemonic(word: "abandon")]),
            syncSpy: syncSpy,
            persistenceSpy: persistenceSpy,
            getWalletsProvider: { store.wallets }
        )

        let sync = Task { await controller.syncPendingWallets(passcode: "1234") }
        await syncSpy.didStartSync.wait()
        store.wallets = []
        syncSpy.blockGate?.open()
        await sync.value

        XCTAssertEqual(persistenceSpy.savedWalletIds, [])
    }

    func test_reconcileBindings_keepsAddressesWrittenWhileTheRequestWasInFlight() async {
        let enrichedAddresses = [
            MultichainWalletAddress(chain: .eth, address: "0xsynced-state"),
            MultichainWalletAddress(chain: .tron, address: "Tsynced-state"),
        ]
        let wallet = makeWallet(
            id: "synced",
            multichain: .multichain(makeState(walletId: "synced-state", syncState: .synced))
        )
        let store = MutableWalletsBox(wallets: [wallet])
        let bindingsSpy = MultichainBindingsSpy()
        bindingsSpy.bindings = DeviceBindings(known: [], unknown: ["synced-state"], extra: [])
        bindingsSpy.onGetDeviceBindings = {
            store.wallets = [
                self.makeWallet(
                    id: wallet.id,
                    multichain: .multichain(
                        self.makeState(
                            walletId: "synced-state",
                            addresses: enrichedAddresses,
                            syncState: .synced
                        )
                    )
                ),
            ]
        }
        let persistenceSpy = MultichainSyncPersistenceSpy()
        let controller = makeController(
            wallets: [],
            mnemonicsSpy: MultichainSyncMnemonicsSpy(mnemonics: [:]),
            syncSpy: MultichainWalletSyncSpy(),
            persistenceSpy: persistenceSpy,
            bindingsSpy: bindingsSpy,
            getWalletsProvider: { store.wallets }
        )

        await controller.reconcileBindings()

        guard case let .multichain(saved)? = persistenceSpy.savedMultichainWallets.first else {
            return XCTFail("expected a multichain state to be saved")
        }
        XCTAssertEqual(saved.addresses, enrichedAddresses)
        XCTAssertEqual(saved.syncState, .pending)
    }
}

/// Stands in for the wallets store: the sync controller reads it again when it writes back, so a
/// test needs the list to change while a call is in flight.
private final class MutableWalletsBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storedWallets: [Wallet]

    var wallets: [Wallet] {
        get { lock.withLock { storedWallets } }
        set { lock.withLock { storedWallets = newValue } }
    }

    init(wallets: [Wallet]) {
        storedWallets = wallets
    }
}

/// Blocks a dependency until the test opens it, so the two passes interleave deterministically.
private final class MultichainSyncGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuations = [UnsafeContinuation<Void, Never>]()
    private var isOpen = false

    func wait() async {
        await withUnsafeContinuation { continuation in
            lock.lock()
            guard !isOpen else {
                lock.unlock()
                continuation.resume()
                return
            }
            continuations.append(continuation)
            lock.unlock()
        }
    }

    func open() {
        lock.lock()
        isOpen = true
        let pending = continuations
        continuations = []
        lock.unlock()
        pending.forEach { $0.resume() }
    }
}

private final class MultichainSyncMnemonicsSpy {
    private let mnemonics: [CoreMnemonicIdentifier: CoreMnemonic]
    private(set) var requestedWalletIds = [[String]]()

    init(mnemonics: [CoreMnemonicIdentifier: CoreMnemonic]) {
        self.mnemonics = mnemonics
    }

    func getMnemonics(
        wallets: [Wallet],
        passcode _: String
    ) async throws -> [CoreMnemonicIdentifier: CoreMnemonic] {
        requestedWalletIds.append(wallets.map(\.id))
        return wallets.reduce(into: [:]) { result, wallet in
            result[wallet.id] = mnemonics[wallet.id]
        }
    }
}

private final class MultichainWalletSyncSpy {
    private(set) var mnemonics = [String]()
    private(set) var syncedWalletIds = [String]()
    var errorWalletIds = Set<String>()
    var syncError = MultichainServiceError.connectionError
    /// Number of leading passes per wallet that fail with a dropped connection before succeeding.
    var transientFailuresByWalletId = [String: Int]()
    /// Holds a sync open so a test can start a reconcile while the first one is still in flight.
    var blockGate: MultichainSyncGate?
    let didStartSync = MultichainSyncGate()

    func syncWallet(
        mnemonic: String,
        state: MultichainWalletState
    ) async throws(MultichainServiceError) {
        mnemonics.append(mnemonic)
        syncedWalletIds.append(state.walletId)
        didStartSync.open()
        if let blockGate {
            await blockGate.wait()
        }
        if let remaining = transientFailuresByWalletId[state.walletId], remaining > 0 {
            transientFailuresByWalletId[state.walletId] = remaining - 1
            throw .connectionError
        }
        if errorWalletIds.contains(state.walletId) {
            throw syncError
        }
    }
}

private final class MultichainAppKeySpy {
    private let lock = NSLock()
    private var missingWalletIds: Set<String>
    private(set) var warmedWalletIds = [String]()
    private(set) var warmedMnemonics = [String]()

    init(missingWalletIds: Set<String> = []) {
        self.missingWalletIds = missingWalletIds
    }

    func hasPersistentAppKey(walletId: String) async -> Bool {
        lock.withLock { !missingWalletIds.contains(walletId) }
    }

    func warmAppKey(walletId: String, mnemonic: String) async {
        lock.withLock {
            missingWalletIds.remove(walletId)
            warmedWalletIds.append(walletId)
            warmedMnemonics.append(mnemonic)
        }
    }
}

private final class MultichainBindingsSpy {
    var bindings = DeviceBindings(known: [], unknown: [], extra: [])
    var error: MultichainServiceError?
    /// Number of leading requests that fail with a dropped connection before succeeding.
    var transientFailures = 0
    var isDeviceKnown = true
    /// Lets a test mutate the wallets store while the reconcile is between read and write.
    var onGetDeviceBindings: (() -> Void)?
    private(set) var requestedWalletIds = [[String]]()
    private(set) var unregisteredWalletIds = [[String]]()

    func getDeviceBindings(walletIds: [String]) async throws(MultichainServiceError) -> DeviceBindings {
        requestedWalletIds.append(walletIds)
        onGetDeviceBindings?()
        if transientFailures > 0 {
            transientFailures -= 1
            throw .connectionError
        }
        if let error {
            throw error
        }
        return bindings
    }

    func unregisterWallets(walletIds: [String]) async throws(MultichainServiceError) {
        unregisteredWalletIds.append(walletIds)
    }
}

private final class MultichainSyncPersistenceSpy {
    private(set) var savedWalletIds = [String]()
    private(set) var savedMultichainWallets = [MultichainWallet]()

    func saveWallet(wallet: Wallet, multichain: MultichainWallet) async {
        savedWalletIds.append(wallet.id)
        savedMultichainWallets.append(multichain)
    }
}

private extension MultichainWalletSyncControllerTests {
    func makeController(
        wallets: [Wallet],
        mnemonicsSpy: MultichainSyncMnemonicsSpy,
        syncSpy: MultichainWalletSyncSpy,
        persistenceSpy: MultichainSyncPersistenceSpy,
        bindingsSpy: MultichainBindingsSpy = MultichainBindingsSpy(),
        appKeySpy: MultichainAppKeySpy = MultichainAppKeySpy(),
        getWalletsProvider: (() -> [Wallet])? = nil
    ) -> MultichainWalletSyncControllerImplementation {
        MultichainWalletSyncControllerImplementation(
            dependencies: MultichainWalletSyncControllerDependencies(
                getWallets: { getWalletsProvider?() ?? wallets },
                getMnemonics: mnemonicsSpy.getMnemonics,
                syncWallet: syncSpy.syncWallet,
                saveWallet: persistenceSpy.saveWallet,
                hasPersistentAppKey: { walletId in
                    await appKeySpy.hasPersistentAppKey(walletId: walletId)
                },
                warmAppKey: { walletId, mnemonic in
                    await appKeySpy.warmAppKey(walletId: walletId, mnemonic: mnemonic)
                },
                getDeviceBindings: bindingsSpy.getDeviceBindings,
                unregisterWallets: bindingsSpy.unregisterWallets,
                isDeviceKnown: { bindingsSpy.isDeviceKnown }
            ),
            // The backoff is real time in production; a suite only cares about the passes.
            sleep: { _ in }
        )
    }

    func makeWallet(
        id: String,
        network: Network = .mainnet,
        kind: WalletKind? = nil,
        multichain: MultichainWallet? = nil
    ) -> Wallet {
        let publicKey = makePublicKey(id: id)
        return Wallet(
            id: id,
            identity: WalletIdentity(
                network: network,
                kind: kind ?? .Regular(publicKey, .v4R2)
            ),
            metaData: WalletMetaData(label: id, tintColor: .SteelGray, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings(),
            multichain: multichain
        )
    }

    func makeState(
        walletId: String,
        addresses: [MultichainWalletAddress]? = nil,
        syncState: MultichainWalletSyncState
    ) -> MultichainWalletState {
        MultichainWalletState(
            walletId: walletId,
            addresses: addresses ?? [
                MultichainWalletAddress(chain: .eth, address: "0x\(walletId)"),
            ],
            syncState: syncState
        )
    }

    func makeMnemonic(word: String) -> CoreMnemonic {
        CoreMnemonic(
            mnemonicWords: Array(repeating: word, count: 12),
            type: .bip39
        )
    }

    func makeMnemonicPhrase(word: String) -> String {
        Array(repeating: word, count: 12).joined(separator: " ")
    }

    func makePublicKey(id: String) -> TonSwift.PublicKey {
        let publicKeyData = Data((id + "-public-key").utf8) + Data(repeating: 0, count: 32)
        return TonSwift.PublicKey(data: Data(publicKeyData.prefix(32)))
    }
}

@testable import KeeperCore
import KeeperCoreSensitive
import TKTestSupport
import TonSwift
import XCTest

final class MultichainWalletEnricherTests: XCTestCase {
    func test_legacyBatteryProofIsPreparedAfterRegistrationBeforeWalletSwitchesIdentity() async {
        let wallet = makeWallet(id: "legacy")
        let persistence = MultichainPersistenceSpy()
        let sync = MultichainSyncSpy()
        var migrated = false
        var resumed = false
        let enricher = makeEnricher(
            wallets: [wallet],
            derived: syncedState,
            syncSpy: sync,
            persistenceSpy: persistence,
            prepareBatteryMigration: { source, destination, mnemonic in
                XCTAssertEqual(sync.syncedStates.count, 1)
                XCTAssertTrue(persistence.savedWalletIds.isEmpty)
                XCTAssertNil(source.multichain)
                XCTAssertEqual(source.identity, wallet.identity)
                XCTAssertEqual(destination.id, wallet.id)
                XCTAssertEqual(destination.identity, wallet.identity)
                XCTAssertEqual(destination.multichainWalletState?.walletId, self.syncedState.walletId)
                XCTAssertEqual(destination.multichainWalletState?.syncState, .synced)
                XCTAssertEqual(mnemonic.type, .bip39)
                migrated = true
            },
            resumeBatteryMigrations: {
                XCTAssertTrue(migrated)
                XCTAssertEqual(persistence.savedWalletIds, [wallet.id])
                resumed = true
            }
        )

        await enricher.enrichMissingWallets(passcode: "1234")

        XCTAssertTrue(migrated)
        XCTAssertTrue(resumed)
        XCTAssertEqual(persistence.savedWalletIds, [wallet.id])
        XCTAssertEqual(persistence.savedMultichainWallets.first, .multichain(syncedState))
    }

    func test_batteryFailureDoesNotStopLegacyWalletEnrichment() async {
        let wallet = makeWallet(id: "legacy")
        let persistence = MultichainPersistenceSpy()
        let enricher = makeEnricher(
            wallets: [wallet],
            derived: syncedState,
            syncSpy: MultichainSyncSpy(),
            persistenceSpy: persistence,
            prepareBatteryMigration: { _, _, _ in throw BatteryAuthorizationError.unavailable }
        )

        await enricher.enrichMissingWallets(passcode: "1234")

        XCTAssertEqual(persistence.savedWalletIds, [wallet.id])
        XCTAssertEqual(persistence.savedMultichainWallets.first, .multichain(syncedState))
    }

    func test_failedLegacyRegistrationKeepsPendingAddressesForSyncWithoutMigratingBattery() async {
        let wallet = makeWallet(id: "legacy")
        let derived = MultichainWalletState(walletId: "new-wallet", addresses: syncedState.addresses)
        let persistence = MultichainPersistenceSpy()
        let enricher = makeEnricher(
            wallets: [wallet],
            derived: derived,
            syncSpy: MultichainSyncSpy(results: [.failure(.apiError(message: "offline"))]),
            persistenceSpy: persistence,
            prepareBatteryMigration: { _, _, _ in XCTFail("An unregistered destination must not receive the battery") }
        )

        await enricher.enrichMissingWallets(passcode: "1234")

        XCTAssertEqual(persistence.savedWalletIds, [wallet.id])
        XCTAssertEqual(persistence.savedMultichainWallets.first, .multichain(.init(
            walletId: derived.walletId,
            addresses: derived.addresses,
            syncState: .pending
        )))
    }

    func test_addingNetworksToMultichainWalletDoesNotMigrateBattery() async {
        for state in [MultichainWalletSyncState.pending, .failed, .synced] {
            let wallet = makeWallet(
                id: "existing",
                multichain: .multichain(.init(walletId: syncedState.walletId, addresses: syncedState.addresses, syncState: state))
            )
            let persistence = MultichainPersistenceSpy()
            let enricher = makeEnricher(
                wallets: [wallet],
                derived: .init(walletId: syncedState.walletId, addresses: syncedState.addresses + [makeAddress(chain: .btc, address: "bc1new", type: .btcP2WPKH)]),
                syncSpy: MultichainSyncSpy(),
                persistenceSpy: persistence,
                prepareBatteryMigration: { _, _, _ in XCTFail("An existing wallet-id battery must not be migrated") }
            )

            await enricher.enrichMissingWallets(passcode: "1234")

            XCTAssertEqual(persistence.savedWalletIds, [wallet.id])
        }
    }

    func test_cancellingProofPreparationKeepsLegacyStateForNextAttempt() async {
        let enteredMigration = TestGate()
        let holdMigration = TestGate()
        let persistence = MultichainPersistenceSpy()
        let enricher = makeEnricher(
            wallets: [makeWallet(id: "legacy")],
            derived: syncedState,
            syncSpy: MultichainSyncSpy(),
            persistenceSpy: persistence,
            prepareBatteryMigration: { _, _, _ in
                await enteredMigration.open()
                try await holdMigration.wait()
            }
        )
        let task = Task { await enricher.enrichMissingWallets(passcode: "1234") }
        try? await enteredMigration.wait()

        task.cancel()
        await task.value

        XCTAssertTrue(persistence.savedWalletIds.isEmpty)
    }

    func test_enrichMissingWallets_loadsMnemonicsInSingleBatchAndRegistersLegacyWallet() async {
        let firstWallet = makeWallet(id: "first-wallet")
        let secondWallet = makeWallet(
            id: "second-wallet",
            multichain: .multichain(
                MultichainWalletState(
                    walletId: "second-wallet-multichain",
                    addresses: [
                        MultichainWalletAddress(chain: .eth, address: "0xexisting"),
                    ]
                )
            )
        )
        let testnetWallet = makeWallet(id: "testnet-wallet", network: .testnet)
        let unavailableWallet = makeWallet(id: "unavailable-wallet", multichain: .unavailable)
        let mnemonicsSpy = MultichainMnemonicsSpy(
            mnemonics: [
                firstWallet.id: CoreMnemonic(
                    mnemonicWords: Array(repeating: "abandon", count: 12),
                    type: .bip39
                ),
                secondWallet.id: CoreMnemonic(
                    mnemonicWords: Array(repeating: "ability", count: 12),
                    type: .bip39
                ),
            ]
        )
        let persistenceSpy = MultichainPersistenceSpy()
        let syncSpy = MultichainSyncSpy()
        let enricher = MultichainWalletEnricherImplementation(
            dependencies: MultichainWalletEnricherDependencies(
                supportedChains: [.eth, .btc],
                getWallets: {
                    [
                        firstWallet,
                        secondWallet,
                        testnetWallet,
                        unavailableWallet,
                    ]
                },
                getMnemonics: mnemonicsSpy.getMnemonics,
                deriveWallet: { _ in
                    MultichainWalletState(
                        walletId: "derived-wallet-id",
                        addresses: [
                            self.makeAddress(chain: .eth, address: "0xderived"),
                            self.makeAddress(chain: .btc, address: "bc1derived", type: .btcP2WPKH),
                        ]
                    )
                },
                syncWallet: syncSpy.sync,
                prepareBatteryMigration: { _, _, _ in },
                saveWallet: persistenceSpy.saveWallet
            )
        )

        await enricher.enrichMissingWallets(passcode: "1234")

        XCTAssertEqual(
            mnemonicsSpy.requestedWalletIds,
            [[firstWallet.id, secondWallet.id]]
        )
        XCTAssertEqual(
            persistenceSpy.savedWalletIds,
            [firstWallet.id, secondWallet.id]
        )
        XCTAssertEqual(
            persistenceSpy.savedMultichainWallets,
            [
                .multichain(
                    MultichainWalletState(
                        walletId: "derived-wallet-id",
                        addresses: [
                            self.makeAddress(chain: .eth, address: "0xderived"),
                            self.makeAddress(chain: .btc, address: "bc1derived", type: .btcP2WPKH),
                        ],
                        syncState: .synced
                    )
                ),
                .multichain(
                    MultichainWalletState(
                        walletId: "derived-wallet-id",
                        addresses: [
                            self.makeAddress(chain: .eth, address: "0xderived"),
                            self.makeAddress(chain: .btc, address: "bc1derived", type: .btcP2WPKH),
                        ],
                        syncState: .pending
                    )
                ),
            ]
        )
        XCTAssertEqual(syncSpy.syncedStates.count, 1)
        XCTAssertEqual(syncSpy.syncedStates.first?.walletId, "derived-wallet-id")
    }

    func test_enrichMissingWallets_registersSyncedWalletBeforeSavingItsNewChains() async {
        let wallet = makeWallet(id: "synced-wallet", multichain: .multichain(syncedState))
        let derived = MultichainWalletState(
            walletId: syncedState.walletId,
            addresses: [
                makeAddress(chain: .eth, address: "0xexisting"),
                makeAddress(chain: .btc, address: "bc1derived", type: .btcP2WPKH),
            ]
        )
        let persistenceSpy = MultichainPersistenceSpy()
        let syncSpy = MultichainSyncSpy()
        let enricher = makeEnricher(
            wallets: [wallet],
            derived: derived,
            syncSpy: syncSpy,
            persistenceSpy: persistenceSpy
        )

        XCTAssertEqual(enricher.missingChains, [.btc])

        await enricher.enrichMissingWallets(passcode: "1234")

        XCTAssertEqual(syncSpy.syncedStates, [derived])
        XCTAssertEqual(
            persistenceSpy.savedMultichainWallets,
            [
                .multichain(
                    MultichainWalletState(
                        walletId: syncedState.walletId,
                        addresses: derived.addresses,
                        syncState: .synced
                    )
                ),
            ]
        )
    }

    func test_enrichMissingWallets_keepsSyncedWalletWhenRegistrationFails() async {
        let wallet = makeWallet(id: "synced-wallet", multichain: .multichain(syncedState))
        let persistenceSpy = MultichainPersistenceSpy()
        let syncSpy = MultichainSyncSpy(results: [.failure(.apiError(message: "rejected"))])
        let enricher = makeEnricher(
            wallets: [wallet],
            derived: MultichainWalletState(
                walletId: syncedState.walletId,
                addresses: syncedState.addresses + [makeAddress(chain: .btc, address: "bc1derived", type: .btcP2WPKH)]
            ),
            syncSpy: syncSpy,
            persistenceSpy: persistenceSpy
        )

        await enricher.enrichMissingWallets(passcode: "1234")

        XCTAssertEqual(syncSpy.syncedStates.count, 1)
        XCTAssertTrue(persistenceSpy.savedMultichainWallets.isEmpty)
        XCTAssertEqual(enricher.missingChains, [.btc])
    }

    func test_enrichMissingWallets_retriesTransientRegistrationFailure() async {
        let wallet = makeWallet(id: "synced-wallet", multichain: .multichain(syncedState))
        let persistenceSpy = MultichainPersistenceSpy()
        let syncSpy = MultichainSyncSpy(results: [.failure(.connectionError), .success(())])
        let enricher = makeEnricher(
            wallets: [wallet],
            derived: MultichainWalletState(
                walletId: syncedState.walletId,
                addresses: syncedState.addresses + [makeAddress(chain: .btc, address: "bc1derived", type: .btcP2WPKH)]
            ),
            syncSpy: syncSpy,
            persistenceSpy: persistenceSpy
        )

        await enricher.enrichMissingWallets(passcode: "1234")

        XCTAssertEqual(syncSpy.syncedStates.count, 2)
        XCTAssertEqual(persistenceSpy.savedWalletIds, [wallet.id])
    }

    func test_missingChains_listsWhatWalletsOnMultichainLackInDisplayOrder() {
        let syncedWallet = makeWallet(id: "synced-wallet", multichain: .multichain(syncedState))
        let pendingWallet = makeWallet(
            id: "pending-wallet",
            multichain: .multichain(
                MultichainWalletState(
                    walletId: "pending-multichain",
                    addresses: [makeAddress(chain: .eth, address: "0xpending"), makeAddress(chain: .btc, address: "bc1pending", type: .btcP2WPKH)]
                )
            )
        )
        let legacyWallet = makeWallet(id: "legacy-wallet")
        let unavailableWallet = makeWallet(id: "unavailable-wallet", multichain: .unavailable)
        let enricher = makeEnricher(
            supportedChains: [.sol, .eth, .btc, .tron],
            wallets: [syncedWallet, pendingWallet, legacyWallet, unavailableWallet],
            derived: MultichainWalletState(walletId: "unexpected", addresses: []),
            syncSpy: MultichainSyncSpy(),
            persistenceSpy: MultichainPersistenceSpy()
        )

        XCTAssertEqual(enricher.missingChains, [.sol, .tron, .btc])
        XCTAssertTrue(enricher.needsStartupEnrichment, "The legacy wallet still needs its first enrichment")
    }

    func test_enrichMissingWallets_savesUnavailableForUnsupportedMnemonic() async {
        let wallet = makeWallet(id: "wallet")
        let mnemonicsSpy = MultichainMnemonicsSpy(
            mnemonics: [
                wallet.id: CoreMnemonic(
                    mnemonicWords: Array(repeating: "abandon", count: 12),
                    type: .ton
                ),
            ]
        )
        let persistenceSpy = MultichainPersistenceSpy()
        let enricher = MultichainWalletEnricherImplementation(
            dependencies: MultichainWalletEnricherDependencies(
                supportedChains: [.eth, .btc],
                getWallets: {
                    [
                        wallet,
                    ]
                },
                getMnemonics: mnemonicsSpy.getMnemonics,
                deriveWallet: { _ in
                    XCTFail("Unsupported mnemonic must not be derived")
                    return MultichainWalletState(walletId: "unexpected", addresses: [])
                },
                syncWallet: MultichainSyncSpy().sync,
                prepareBatteryMigration: { _, _, _ in XCTFail("TON mnemonics must not migrate the battery") },
                saveWallet: persistenceSpy.saveWallet
            )
        )

        await enricher.enrichMissingWallets(passcode: "1234")

        XCTAssertEqual(persistenceSpy.savedWalletIds, [wallet.id])
        XCTAssertEqual(persistenceSpy.savedMultichainWallets, [.unavailable])
    }

    func test_enrichMissingWalletsSavesOnlyPreferredTONAddressType() async {
        let v4Wallet = makeWallet(id: "v4-wallet", contractVersion: .v4R2)
        let v5Wallet = makeWallet(id: "v5-wallet", contractVersion: .v5R1)
        let mnemonicsSpy = MultichainMnemonicsSpy(
            mnemonics: [
                v4Wallet.id: CoreMnemonic(
                    mnemonicWords: Array(repeating: "abandon", count: 12),
                    type: .bip39
                ),
                v5Wallet.id: CoreMnemonic(
                    mnemonicWords: Array(repeating: "ability", count: 12),
                    type: .bip39
                ),
            ]
        )
        let persistenceSpy = MultichainPersistenceSpy()
        let enricher = MultichainWalletEnricherImplementation(
            dependencies: MultichainWalletEnricherDependencies(
                supportedChains: [.ton],
                getWallets: { [v4Wallet, v5Wallet] },
                getMnemonics: mnemonicsSpy.getMnemonics,
                deriveWallet: { _ in
                    MultichainWalletState(
                        walletId: "derived-wallet-id",
                        addresses: [
                            self.makeAddress(chain: .ton, address: "ton-v4", type: .tonV4R2),
                            self.makeAddress(chain: .ton, address: "ton-v5", type: .tonV5R1),
                        ]
                    )
                },
                syncWallet: MultichainSyncSpy().sync,
                prepareBatteryMigration: { _, _, _ in },
                saveWallet: persistenceSpy.saveWallet
            )
        )

        await enricher.enrichMissingWallets(passcode: "1234")

        XCTAssertEqual(
            persistenceSpy.savedMultichainWallets,
            [
                .multichain(
                    MultichainWalletState(
                        walletId: "derived-wallet-id",
                        addresses: [self.makeAddress(chain: .ton, address: "ton-v4", type: .tonV4R2)],
                        syncState: .synced
                    )
                ),
                .multichain(
                    MultichainWalletState(
                        walletId: "derived-wallet-id",
                        addresses: [self.makeAddress(chain: .ton, address: "ton-v5", type: .tonV5R1)],
                        syncState: .synced
                    )
                ),
            ]
        )

        let enrichedWallets = [
            makeWallet(
                id: v4Wallet.id,
                contractVersion: .v4R2,
                multichain: persistenceSpy.savedMultichainWallets[0]
            ),
            makeWallet(
                id: v5Wallet.id,
                contractVersion: .v5R1,
                multichain: persistenceSpy.savedMultichainWallets[1]
            ),
        ]
        let recheck = MultichainWalletEnricherImplementation(
            dependencies: MultichainWalletEnricherDependencies(
                supportedChains: [.ton],
                getWallets: { enrichedWallets },
                getMnemonics: { _, _ in [:] },
                deriveWallet: { _ in
                    XCTFail("Enriched wallets must not be derived again")
                    return MultichainWalletState(walletId: "unexpected", addresses: [])
                },
                syncWallet: MultichainSyncSpy().sync,
                prepareBatteryMigration: { _, _, _ in },
                saveWallet: { _, _ in }
            )
        )

        XCTAssertFalse(recheck.needsStartupEnrichment)
    }

    func test_needsStartupEnrichment_whenRequiredAddressHasNoPublicKey() {
        let wallet = makeWallet(
            id: "legacy-wallet",
            multichain: .multichain(
                MultichainWalletState(
                    walletId: "multichain-wallet-id",
                    addresses: [.init(chain: .eth, address: "0xlegacy")]
                )
            )
        )
        let enricher = MultichainWalletEnricherImplementation(
            dependencies: MultichainWalletEnricherDependencies(
                supportedChains: [.eth],
                getWallets: { [wallet] },
                getMnemonics: { _, _ in [:] },
                deriveWallet: { _ in
                    XCTFail("Wallet must not be derived while checking enrichment")
                    return MultichainWalletState(walletId: "unexpected", addresses: [])
                },
                syncWallet: MultichainSyncSpy().sync,
                prepareBatteryMigration: { _, _, _ in },
                saveWallet: { _, _ in }
            )
        )

        XCTAssertTrue(enricher.needsStartupEnrichment)
    }
}

private final class MultichainMnemonicsSpy {
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

private final class MultichainPersistenceSpy {
    private(set) var savedWalletIds = [String]()
    private(set) var savedMultichainWallets = [MultichainWallet]()

    func saveWallet(wallet: Wallet, multichain: MultichainWallet) async {
        savedWalletIds.append(wallet.id)
        savedMultichainWallets.append(multichain)
    }
}

/// Answers each registration with the next result, then succeeds.
private final class MultichainSyncSpy {
    private var results: [Result<Void, MultichainServiceError>]
    private(set) var syncedStates = [MultichainWalletState]()

    init(results: [Result<Void, MultichainServiceError>] = []) {
        self.results = results
    }

    func sync(mnemonic _: String, state: MultichainWalletState) async throws(MultichainServiceError) {
        syncedStates.append(state)
        guard !results.isEmpty else { return }
        try results.removeFirst().get()
    }
}

private extension MultichainWalletEnricherTests {
    var syncedState: MultichainWalletState {
        MultichainWalletState(
            walletId: "synced-multichain",
            addresses: [makeAddress(chain: .eth, address: "0xexisting")],
            syncState: .synced
        )
    }

    func makeEnricher(
        supportedChains: Set<MultichainChain> = [.eth, .btc],
        wallets: [Wallet],
        derived: MultichainWalletState,
        syncSpy: MultichainSyncSpy,
        persistenceSpy: MultichainPersistenceSpy,
        prepareBatteryMigration: @escaping (Wallet, Wallet, CoreMnemonic) async throws -> Void = { _, _, _ in },
        resumeBatteryMigrations: @escaping () async -> Void = {}
    ) -> MultichainWalletEnricherImplementation {
        MultichainWalletEnricherImplementation(
            dependencies: MultichainWalletEnricherDependencies(
                supportedChains: supportedChains,
                getWallets: { wallets },
                getMnemonics: { wallets, _ in
                    wallets.reduce(into: [:]) { result, wallet in
                        result[wallet.id] = CoreMnemonic(mnemonicWords: Array(repeating: "abandon", count: 12), type: .bip39)
                    }
                },
                deriveWallet: { _ in derived },
                syncWallet: syncSpy.sync,
                prepareBatteryMigration: prepareBatteryMigration,
                saveWallet: persistenceSpy.saveWallet,
                resumeBatteryMigrations: resumeBatteryMigrations
            ),
            sleep: { _ in }
        )
    }

    func makeAddress(
        chain: MultichainChain,
        address: String,
        type: MultichainWalletAddressType? = nil
    ) -> MultichainWalletAddress {
        MultichainWalletAddress(
            chain: chain,
            address: address,
            type: type,
            publicKey: MultichainPublicKey(
                defaultHex: "default-public-key",
                segWit: "segwit-public-key"
            )
        )
    }

    func makeWallet(
        id: String,
        network: Network = .mainnet,
        contractVersion: WalletContractVersion = .v4R2,
        multichain: MultichainWallet? = nil
    ) -> Wallet {
        let publicKeyData = Data((id + "-public-key").utf8) + Data(repeating: 0, count: 32)
        let publicKey = TonSwift.PublicKey(data: Data(publicKeyData.prefix(32)))
        return Wallet(
            id: id,
            identity: WalletIdentity(network: network, kind: .Regular(publicKey, contractVersion)),
            metaData: WalletMetaData(label: id, tintColor: .SteelGray, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings(),
            multichain: multichain
        )
    }
}

import ChainKit
import KeeperCoreSensitive
import TKAppInfo
import TKKeychain
import TKLogging
import UIKit

public final class MultichainAssembly {
    func batteryPurchaser(service: BatteryServiceImplementation) -> BatteryPurchaser {
        BatteryPurchaser(
            service: service,
            relayer: BatteryEVMGaslessRelayer(service: service),
            sign: chainKitServiceImplementation.signBatteryPurchase
        )
    }

    public private(set) lazy var chainKitService: ChainKitService = chainKitServiceImplementation

    /// Signs the documents of a relayed operation: the same keys `chainKitService` sends with.
    private(set) lazy var relayedOperationSigner: MultichainRelayedOperationSigner = chainKitServiceImplementation

    /// The gate every multichain send clears before it signs.
    private(set) lazy var sendGate = OperationGate(configuration: configuration, validatingWith: chainKitClient)

    /// The gate every relayed swap clears before it signs.
    private(set) lazy var swapGate = OperationGate(configuration: configuration, validatingWith: chainKitClient)

    private lazy var chainKitServiceImplementation = ChainKitServiceImplementation(
        supportedChains: supportedChains,
        mnemonicAccess: mnemonicAccess,
        client: chainKitClient,
        gate: sendGate,
        assetDetailsProvider: assetDetailsProvider
    )

    /// The wallet's own details of an asset, a hidden one included, which fees are shown with.
    private lazy var assetDetailsProvider: (String, Wallet) async -> MultichainAssetDetails? = { [multichainAssetBalanceProvider] assetId, wallet in
        await multichainAssetBalanceProvider.loadAsset(for: assetId, wallet: wallet, includingHidden: true)?.asset
    }

    public private(set) lazy var walletSynchronizer: MultichainWalletSynchronizer = MultichainWalletSynchronizerImplementation(
        chainKitService: chainKitService,
        multichainService: multichainService,
        authService: multichainAuthService
    )

    public private(set) lazy var multichainAuthService: MultichainAuthService = MultichainAuthServiceImplementation(
        clientAPI: multichainAuthClientAPI,
        deviceAuth: deviceAuthService,
        pendingUnregisterStore: MultichainPendingUnregisterStore(keychainVault: keychainVault)
    )

    /// Set by the app layer: a rotated device id invalidates the push subscription too, and only
    /// the app layer owns it. The session starts at launch, before the app layer sets this, so a
    /// rotation that comes first waits for it.
    public var didChangeDevice: (() -> Void)? {
        // On the next main-actor turn: the handler's owner finishes its own setup first.
        didSet { Task { @MainActor [weak self] in self?.deliverPendingDeviceChange() } }
    }

    private var hasPendingDeviceChange = false

    /// Owns the rotation state; the two hops below keep the assembly's lazy graph and the
    /// app-layer handler on main, which is the only place they may be touched from.
    private lazy var deviceChangeController = MultichainDeviceChangeController(
        reconcileBindings: { [weak self] in await self?.reconcileBindingsOnMain() },
        didChangeDevice: { [weak self] in await self?.notifyDidChangeDeviceOnMain() }
    )

    /// Entry point for the owner of `DeviceAuthService`, which sits above this assembly because
    /// the battery needs it too. `@MainActor` keeps the lazy graph resolution on main.
    @MainActor
    func handleDeviceChange() async {
        await deviceChangeController.handle()
    }

    /// Binds one wallet's addresses to this device, warming its app key first. The enricher, the
    /// sync controller and the QA chain remover all register a wallet this one way.
    private lazy var syncWallet: (_ mnemonic: String, _ state: MultichainWalletState) async throws(MultichainServiceError) -> Void = { [walletSynchronizer, walletAuthTokenProvider] mnemonic, state throws(MultichainServiceError) in
        await walletAuthTokenProvider.warm(walletId: state.walletId, mnemonic: mnemonic)
        try await walletSynchronizer.sync(mnemonic: mnemonic, state: state)
    }

    private lazy var syncLedgerWallet: (_ state: MultichainWalletState) async throws(MultichainServiceError) -> Void = { [walletSynchronizer, walletAuthTokenProvider] state throws(MultichainServiceError) in
        guard let appKey = await walletAuthTokenProvider.persistentAppKey(walletId: state.walletId) else {
            throw .apiError(message: "no app key kept for Ledger wallet \(state.walletId)")
        }
        try await walletSynchronizer.sync(appPrivateKey: appKey, state: state)
    }

    public private(set) lazy var walletAddressesEnricher: MultichainWalletEnricher = MultichainWalletEnricherImplementation(
        dependencies: MultichainWalletEnricherDependencies(
            supportedChains: Set(supportedChains),
            getWallets: { [walletsStore] in
                walletsStore.wallets
            },
            getMnemonics: { [mnemonicAccess] wallets, passcode in
                try await mnemonicAccess.getMnemonics(wallets: wallets, passcode: passcode)
            },
            deriveWallet: { [chainKitService] mnemonic in
                try chainKitService.makeWalletState(mnemonic: mnemonic)
            },
            syncWallet: syncWallet,
            prepareBatteryMigration: { [legacyBatteryMigrationController] _, destination, mnemonic in
                try await legacyBatteryMigrationController.prepare(wallet: JSONEncoder().encode(destination), mnemonic: mnemonic)
            },
            saveWallet: { [walletsStore] wallet, multichain in
                await walletsStore.setWalletMultichain(wallet: wallet, multichain: multichain)
            },
            resumeBatteryMigrations: { [legacyBatteryMigrationController] in
                await legacyBatteryMigrationController.resume()
            }
        )
    )

    public private(set) lazy var walletChainRemover = MultichainWalletChainRemover(
        dependencies: MultichainWalletChainRemover.Dependencies(
            getMnemonics: { [mnemonicAccess] wallets, passcode in
                try await mnemonicAccess.getMnemonics(wallets: wallets, passcode: passcode)
            },
            syncWallet: syncWallet,
            saveWallet: { [walletsStore] wallet, multichain in
                await walletsStore.setWalletMultichain(wallet: wallet, multichain: multichain)
            }
        )
    )

    public private(set) lazy var walletSyncController: MultichainWalletSyncController = MultichainWalletSyncControllerImplementation(
        dependencies: MultichainWalletSyncControllerDependencies(
            getWallets: { [walletsStore] in
                walletsStore.wallets
            },
            getMnemonics: { [mnemonicAccess] wallets, passcode in
                try await mnemonicAccess.getMnemonics(wallets: wallets, passcode: passcode)
            },
            syncWallet: syncWallet,
            syncLedgerWallet: syncLedgerWallet,
            saveWallet: { [walletsStore] wallet, multichain in
                guard case let .multichain(desired) = multichain else {
                    await walletsStore.setWalletMultichain(wallet: wallet, multichain: multichain)
                    return
                }
                await walletsStore.updateWalletMultichain(wallet: wallet) { stored in
                    guard case let .multichain(current) = stored.multichain,
                          current.walletId == desired.walletId
                    else {
                        return nil
                    }
                    return .multichain(
                        MultichainWalletState(
                            walletId: current.walletId,
                            addresses: current.addresses,
                            syncState: desired.syncState
                        )
                    )
                }
            },
            hasPersistentAppKey: { [walletAuthTokenProvider] walletId in
                await walletAuthTokenProvider.hasPersistentAppKey(walletId: walletId)
            },
            warmAppKey: { [walletAuthTokenProvider] walletId, mnemonic in
                await walletAuthTokenProvider.warm(walletId: walletId, mnemonic: mnemonic)
            },
            getDeviceBindings: { [multichainAuthService] walletIds throws(MultichainServiceError) in
                try await multichainAuthService.deviceBindings(walletIds: walletIds)
            },
            unregisterWallets: { [multichainAuthService] walletIds throws(MultichainServiceError) in
                try await multichainAuthService.unregisterWallets(walletIds: walletIds)
            },
            isDeviceKnown: { [multichainAuthService] in
                await multichainAuthService.isDeviceKnown()
            }
        )
    )

    public private(set) lazy var raffleImportReporter = RaffleImportReporter(
        resolveRegisteredWalletId: { [walletsStore] walletId in
            guard
                case let .multichain(state) = walletsStore.getWallet(id: walletId)?.multichain,
                state.syncState == .synced
            else { return nil }
            return state.walletId
        },
        markImport: { [multichainService] walletId, importedWalletId throws(MultichainServiceError) in
            try await multichainService.markRaffleImport(walletId: walletId, importedWalletId: importedWalletId)
        }
    )

    public private(set) lazy var supportedChains: [MultichainChain] = MultichainChain.displayOrder

    /// Adds the chains `keys` reach that a multichain Ledger `wallet` has no address on, and returns them.
    /// The backend accepts the new addresses before they are saved, as for a mnemonic wallet's new networks.
    public func addLedgerNetworks(wallet: Wallet, keys: LedgerAppKeys, chains: [MultichainChain]) async throws -> [MultichainChain] {
        let wallet = walletsStore.getWallet(id: wallet.id) ?? wallet
        guard wallet.kind == .ledger,
              let networks = try wallet.multichainWalletState?.addingLedgerNetworks(keys, chains: chains)
        else {
            return []
        }
        try await MultichainRetry.run { () async throws(MultichainServiceError) in
            try await self.syncLedgerWallet(networks.state)
        }
        await walletsStore.setWalletMultichain(wallet: wallet, multichain: .multichain(networks.state))
        return networks.added
    }

    /// Makes a TON-only Ledger wallet multichain in place — the same wallet, name and connections — with the
    /// addresses and app key `account` yields, and returns the chains it gained; one that would gain none stays as it
    /// is. The binding pass registers it, as it registers a newly paired multichain Ledger.
    public func upgradeLedgerWallet(_ wallet: Wallet, account: LedgerMultichainAccount, chains: [MultichainChain]) async throws -> [MultichainChain] {
        let wallet = walletsStore.getWallet(id: wallet.id) ?? wallet
        guard case let .Ledger(publicKey, _, _) = wallet.identity.kind, !wallet.isMultichain,
              let upgrade = try account.upgrade(tonPublicKey: publicKey.data, chains: chains)
        else {
            return []
        }
        await walletAuthTokenProvider.persistLedgerKeys(seed: upgrade.seed, appKey: upgrade.appPrivateKey, walletId: upgrade.state.walletId)
        await walletsStore.setWalletMultichain(wallet: wallet, multichain: .multichain(upgrade.state))
        await walletSyncController.reconcileBindings()
        return upgrade.added
    }

    /// QA: makes every multichain Ledger wallet TON-only again, so that its upgrade can be tried once more.
    public func dropLedgerMultichain() async -> Int {
        let wallets = walletsStore.wallets.filter { $0.kind == .ledger && $0.isMultichain }
        for wallet in wallets {
            await walletsStore.setWalletMultichain(wallet: wallet, multichain: nil)
        }
        return wallets.count
    }

    public private(set) lazy var newChainBadgeService: NewChainBadgeService = NewChainBadgeServiceImplementation()

    func keepTradingKey(wallet: Wallet, mnemonic: CoreMnemonic) async {
        guard wallet.kind == .regular, !wallet.isWalletTg, wallet.network == .mainnet, mnemonic.type == .bip39 else { return }
        do {
            let cryptoWallet = try CryptoWallet.Companion.shared.fromMnemonic(mnemonic_: mnemonic.mnemonicWords.joined(separator: " "))
            try await tradingCredentials(wallet: wallet).keepTradingKey(cryptoWallet: cryptoWallet)
        } catch {
            Log.perps.w("trading key not kept wallet=\(wallet.id)", error: error)
        }
    }

    public func warmMissingTradingKeys(passcode: String) async {
        let wallets = walletsStore.wallets.filter { wallet in
            guard wallet.kind == .regular, wallet.network == .mainnet, wallet.multichainWalletState != nil else { return false }
            return (try? tradingCredentials(wallet: wallet).loadL2PrivateKey()) == nil
        }
        guard !wallets.isEmpty else { return }
        do {
            let mnemonics = try await mnemonicAccess.getMnemonics(wallets: wallets, passcode: passcode)
            for wallet in wallets {
                guard !Task.isCancelled else { return }
                if let mnemonic = mnemonics[wallet.id] {
                    await keepTradingKey(wallet: wallet, mnemonic: mnemonic)
                }
            }
        } catch {
            Log.perps.w("failed to load mnemonics for trading keys", error: error)
        }
    }

    private func tradingCredentials(wallet: Wallet) -> LighterCredentialsStore {
        LighterCredentialsStore(keychainVault: keychainVault, walletId: wallet.id, environment: PerpsEnvironment.storage)
    }

    public private(set) lazy var multichainAssetBalanceProvider: MultichainAssetBalanceProvider = MultichainAssetBalanceProvider(
        balanceService: multichainService,
        currencyStore: currencyStore,
        visibilityChangesController: visibilityChangesController
    )

    public private(set) lazy var realtimeManager: MultichainRealtimeManager = {
        let transport = MultichainRealtimeClient(
            tokenSource: RealtimeTokenSource(clientAPI: multichainClientAPI),
            userAgent: appInfoProvider.userAgent,
            version: appInfoProvider.version
        )
        let manager = MultichainRealtimeManager(
            walletsStore: walletsStore,
            transport: transport,
            endpointProvider: { [configuration] in
                configuration.value(\.multichain.realtime) ?? BootConfiguration.defaultMultichainRealtimeURL
            }
        )
        configuration.addUpdateObserver(manager) { $0.configurationDidChange() }
        manager.start()
        return manager
    }()

    private(set) lazy var chainKitSwapPipeline: ChainKitSwapPipeline = ChainKitSwapPipelineImplementation(
        mnemonicAccess: mnemonicAccess,
        client: chainKitClient,
        assetDetailsProvider: assetDetailsProvider,
        relays: { [configuration] in configuration.relaysGasless(on: $0) }
    )

    private(set) lazy var swapOperationSteps: MultichainSwapOperationSteps = ChainKitSwapOperationSteps(
        client: chainKitClient,
        unlocker: SwapWalletUnlocker(mnemonicAccess: mnemonicAccess),
        assetDetailsProvider: assetDetailsProvider
    )

    /// The one ChainKit client in the app: it carries the node manifest and the device session
    /// those nodes are resolved under, so a second instance would mean a second, differently
    /// authenticated view of the same chains.
    private(set) lazy var chainKitClient: CryptoKitClient = {
        let networkConfig = ModuleNetConfig(
            isLogging: !UIApplication.shared.isAppStoreEnvironment,
            logger: ChainKitNetLogger(),
            userAgent: appInfoProvider.userAgent,
            sessionProvider: ChainKitSessionTokenProvider(deviceAuth: deviceAuthService),
            nodeManifestHost: ChainKitNodeManifestHost(configuration: configuration)
        )
        return CryptoKitClient(
            netModule: ModuleNetModule(netConfig: networkConfig)
        )
    }()

    private let appInfoProvider: AppInfoProvider
    private let mnemonicAccess: MnemonicAccess
    private let walletsStore: WalletsStore
    private let multichainService: MultichainService
    private let multichainClientAPI: MultichainClientAPI
    private let multichainAuthClientAPI: MultichainAuthClientAPI
    private let multichainSwapService: MultichainSwapService
    private let pendingTransactionsService: PendingTransactionsService
    private let visibilityChangesController: VisibilityChangesController
    private let currencyStore: CurrencyStore
    private let configuration: Configuration
    private let keychainVault: TKKeychainVault
    private let deviceAuthService: DeviceAuthProviding
    let legacyBatteryMigrationController: LegacyBatteryMigrationController
    let walletAuthTokenProvider: WalletAuthTokenProvider

    func walletAuthDependencies() -> MultichainWalletAuthDependencies {
        MultichainWalletAuthDependencies(
            deviceAuth: deviceAuthService,
            walletAuthTokenProvider: walletAuthTokenProvider
        )
    }

    init(
        appInfoProvider: AppInfoProvider,
        mnemonicAccess: MnemonicAccess,
        walletsStore: WalletsStore,
        multichainService: MultichainService,
        multichainClientAPI: MultichainClientAPI,
        multichainAuthClientAPI: MultichainAuthClientAPI,
        multichainSwapService: MultichainSwapService,
        pendingTransactionsService: PendingTransactionsService,
        visibilityChangesController: VisibilityChangesController,
        currencyStore: CurrencyStore,
        configuration: Configuration,
        keychainVault: TKKeychainVault,
        deviceAuthService: DeviceAuthProviding,
        legacyBatteryMigrationController: LegacyBatteryMigrationController,
        walletAuthTokenProvider: WalletAuthTokenProvider
    ) {
        self.appInfoProvider = appInfoProvider
        self.mnemonicAccess = mnemonicAccess
        self.walletsStore = walletsStore
        self.multichainService = multichainService
        self.multichainClientAPI = multichainClientAPI
        self.multichainAuthClientAPI = multichainAuthClientAPI
        self.multichainSwapService = multichainSwapService
        self.pendingTransactionsService = pendingTransactionsService
        self.visibilityChangesController = visibilityChangesController
        self.currencyStore = currencyStore
        self.configuration = configuration
        self.keychainVault = keychainVault
        self.deviceAuthService = deviceAuthService
        self.legacyBatteryMigrationController = legacyBatteryMigrationController
        self.walletAuthTokenProvider = walletAuthTokenProvider
    }

    public func resumeLegacyBatteryMigrations() async {
        await legacyBatteryMigrationController.resume()
    }
}

/// The lazy graph is not thread-safe, so both entry points the device-change controller calls back
/// into resolve their dependency on main. Nothing but `Void` crosses the hop.
@MainActor
private extension MultichainAssembly {
    func reconcileBindingsOnMain() async {
        await walletSyncController.reconcileBindings()
    }

    func notifyDidChangeDeviceOnMain() {
        guard let didChangeDevice else {
            hasPendingDeviceChange = true
            return
        }
        didChangeDevice()
    }

    func deliverPendingDeviceChange() {
        guard hasPendingDeviceChange, let didChangeDevice else { return }
        hasPendingDeviceChange = false
        didChangeDevice()
    }
}

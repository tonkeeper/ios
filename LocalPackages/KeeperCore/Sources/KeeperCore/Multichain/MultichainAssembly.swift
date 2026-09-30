import ChainKit
import TKAppInfo
import TKKeychain
import UIKit

public final class MultichainAssembly {
    public private(set) lazy var chainKitService: ChainKitService = {
        let assetBalanceProvider = multichainAssetBalanceProvider
        return ChainKitServiceImplementation(
            supportedChains: supportedChains,
            mnemonicAccess: mnemonicAccess,
            client: chainKitClient,
            assetDetailsProvider: { [assetBalanceProvider] assetId, wallet in
                await assetBalanceProvider
                    .loadAsset(
                        for: assetId,
                        wallet: wallet,
                        includingHidden: true
                    )?
                    .asset
            }
        )
    }()

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
    /// the app layer owns it.
    public var didChangeDevice: (() -> Void)?

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
            syncWallet: { [walletSynchronizer, walletAuthTokenProvider] mnemonic, state throws(MultichainServiceError) in
                await walletAuthTokenProvider.warm(walletId: state.walletId, mnemonic: mnemonic)
                try await walletSynchronizer.sync(mnemonic: mnemonic, state: state)
            },
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

    private(set) lazy var chainKitSwapPipeline: ChainKitSwapPipeline = {
        let assetBalanceProvider = multichainAssetBalanceProvider
        return ChainKitSwapPipelineImplementation(
            mnemonicAccess: mnemonicAccess,
            client: chainKitClient,
            assetDetailsProvider: { [assetBalanceProvider] assetId, wallet in
                await assetBalanceProvider
                    .loadAsset(
                        for: assetId,
                        wallet: wallet,
                        includingHidden: true
                    )?
                    .asset
            }
        )
    }()

    /// The one ChainKit client in the app: it carries the node manifest and the device session
    /// those nodes are resolved under, so a second instance would mean a second, differently
    /// authenticated view of the same chains.
    private(set) lazy var chainKitClient: CryptoKitClient = {
        let networkConfig = ModuleNetConfig(
            isLogging: !UIApplication.shared.isAppStoreEnvironment,
            logger: ChainKitNetLogger(),
            userAgent: appInfoProvider.userAgent,
            sessionProvider: ChainKitSessionTokenProvider(deviceAuth: deviceAuthService)
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
        self.walletAuthTokenProvider = walletAuthTokenProvider
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
        didChangeDevice?()
    }
}

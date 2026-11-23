import Foundation
import KeeperCoreSensitive
import TKFeatureFlags
import TKLogging
import TonSwift

public final class Assembly {
    public struct Dependencies {
        public let cacheURL: URL
        public let sharedCacheURL: URL
        public let featureFlags: TKFeatureFlags
        public let tkAppSettings: TKAppSettings
        public let appInfoProvider: AppInfoProvider
        public let seedProvider: () -> String
        public let firebaseUserIdProvider: @Sendable () -> String?
        /// Firebase project number the pusher routes by; immutable after the first device registration.
        public let pushAppIdProvider: @Sendable () -> Int64?

        public init(
            cacheURL: URL,
            sharedCacheURL: URL,
            appInfoProvider: AppInfoProvider,
            featureFlags: TKFeatureFlags,
            tkAppSettings: TKAppSettings = UserDefaultsTKAppSettings(),
            seedProvider: @escaping () -> String,
            firebaseUserIdProvider: @escaping @Sendable () -> String? = { nil },
            pushAppIdProvider: @escaping @Sendable () -> Int64? = { nil }
        ) {
            self.cacheURL = cacheURL
            self.sharedCacheURL = sharedCacheURL
            self.appInfoProvider = appInfoProvider
            self.featureFlags = featureFlags
            self.tkAppSettings = tkAppSettings
            self.seedProvider = seedProvider
            self.firebaseUserIdProvider = firebaseUserIdProvider
            self.pushAppIdProvider = pushAppIdProvider
        }
    }

    private let coreAssembly: CoreAssembly
    private let deviceTokenStore: DeviceTokenStore
    public lazy var repositoriesAssembly = RepositoriesAssembly(
        coreAssembly: coreAssembly
    )
    private lazy var secureAssembly = SecureAssembly(
        coreAssembly: coreAssembly,
        didUnlockMnemonics: { [weak self] mnemonics in
            await self?.prepareLegacyBatteryMigrations(mnemonics)
        }
    )
    public lazy var transactionsManagementAssembly = TransactionsManagementAssembly(
        coreAssembly: coreAssembly
    )
    private lazy var bootConfigurationAPIAssembly = BootConfigurationAPIAssembly(
        appInfoProvider: dependencies.appInfoProvider,
        requestContextProvider: { [repositoriesAssembly] in
            BootConfigurationRequestContext(
                features: ["multichain"],
                walletID: (try? repositoriesAssembly.keeperInfoRepository().getKeeperInfo())?
                    .currentWallet
                    .multichainWalletState?
                    .walletId
            )
        }
    )
    private lazy var currenciesAPIAssembly = CurrenciesAPIAssembly(
        appInfoProvider: dependencies.appInfoProvider
    )
    public private(set) lazy var configurationAssembly = ConfigurationAssembly(
        bootConfigurationAPIAssembly: bootConfigurationAPIAssembly,
        featureFlags: dependencies.featureFlags,
        tkAppSettings: dependencies.tkAppSettings,
        coreAssembly: coreAssembly
    )
    private lazy var buySellAssembly = BuySellAssembly(
        tonkeeperApiAssembly: tonkeeperApiAssembly,
        coreAssembly: coreAssembly
    )
    private lazy var knownAccountsAssembly = KnownAccountsAssembly(
        tonkeeperApiAssembly: tonkeeperApiAssembly,
        coreAssembly: coreAssembly
    )

    private lazy var backgroundUpdateAssembly = BackgroundUpdateAssembly(
        apiAssembly: apiAssembly,
        storesAssembly: storesAssembly,
        coreAssembly: coreAssembly
    )
    public lazy var tronUSDTAssembly = TronUSDTAssembly(
        secureAssembly: secureAssembly,
        storesAssembly: storesAssembly,
        batteryAPIAssembly: batteryAPIAssembly,
        batteryAssembly: batteryAssembly,
        configurationAssembly: configurationAssembly,
        repositoriesAssembly: repositoriesAssembly
    )

    lazy var apiAssembly = APIAssembly(
        configurationAssembly: configurationAssembly,
        firebaseUserIdProvider: dependencies.firebaseUserIdProvider
    )
    lazy var tonkeeperApiAssembly = TonkeeperAPIAssembly(
        appInfoProvider: dependencies.appInfoProvider,
        coreAssembly: coreAssembly,
        tkAppSettings: dependencies.tkAppSettings
    )
    private lazy var nativeSwapAPIAssembly = NativeSwapAPIAssembly(configurationAssembly: configurationAssembly)
    private lazy var onRampAPIAssembly = OnRampAPIAssembly(
        configurationAssembly: configurationAssembly,
        appInfoProvider: dependencies.appInfoProvider,
        apiAssembly: apiAssembly
    )
    private lazy var multichainSwapAPIAssembly = MultichainSwapAPIAssembly(
        appInfoProvider: dependencies.appInfoProvider,
        apiAssembly: apiAssembly
    )
    private lazy var multichainRampAPIAssembly = MultichainRampAPIAssembly(
        appInfoProvider: dependencies.appInfoProvider,
        apiAssembly: apiAssembly,
        deviceAuth: { [weak self] in self?.deviceAuthService }
    )
    private lazy var tradingAPIAssembly = TradingAPIAssembly(configurationAssembly: configurationAssembly)
    private lazy var multichainAPIAssembly: MultichainAPIAssembly = MultichainAPIAssembly(
        appInfoProvider: dependencies.appInfoProvider,
        apiAssembly: apiAssembly,
        walletAuth: { [weak self] in
            guard let self else { return nil }
            return MultichainWalletAuthDependencies(
                deviceAuth: deviceAuthService,
                walletAuthTokenProvider: walletAuthTokenProvider
            )
        }
    )
    private lazy var earnAssembly = EarnAssembly(
        apiAssembly: apiAssembly,
        appInfoProvider: dependencies.appInfoProvider,
        configuration: configurationAssembly.configuration,
        walletsStore: storesAssembly.walletsStore,
        fileSystemVault: coreAssembly.fileSystemVault(),
        walletAuth: { [weak self] in
            guard let self else { return nil }
            return MultichainWalletAuthDependencies(
                deviceAuth: deviceAuthService,
                walletAuthTokenProvider: walletAuthTokenProvider
            )
        }
    )
    private lazy var tonProofTokenService = TonProofTokenServiceImplementation(
        keeperInfoRepository: repositoriesAssembly.keeperInfoRepository(),
        tonProofTokenRepository: repositoriesAssembly.tonProofTokenRepository(),
        api: apiAssembly.api
    )
    /// Above `MultichainAssembly` because the battery needs the same session: routing it through
    /// the multichain assembly would close a cycle over `ServicesAssembly`/`BatteryAssembly`.
    private lazy var deviceAuthService: DeviceAuthProviding = DeviceAuthServiceFactory.make(
        api: multichainAPIAssembly.multichainAuthAPI(),
        keychainVault: coreAssembly.keychainVault,
        tokenStore: deviceTokenStore,
        appInfoProvider: dependencies.appInfoProvider,
        appIdProvider: dependencies.pushAppIdProvider,
        // `@MainActor` resolves the lazy graph on main; the multichain assembly owns the
        // rotation state itself.
        didChangeDevice: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                await self.multichainAssembly.handleDeviceChange()
            }
        }
    )
    /// Above `MultichainAssembly` for the same reason as `deviceAuthService`: the battery reads the
    /// wallet credential too, and reaching it through that assembly would close a cycle over
    /// `ServicesAssembly`/`BatteryAssembly`. `ChainKitService` is resolved on first use, which is
    /// long after the graph is built — and, in an extension, can be after the graph is gone, so the
    /// reference is `weak`: the provider is reachable from services that outlive this assembly.
    private lazy var walletAuthTokenProvider = WalletAuthTokenProvider(
        chainKitService: { [weak self] in self?.multichainAssembly.chainKitService },
        store: WalletAuthKeychainStore(keychainVault: coreAssembly.keychainVault)
    )
    private lazy var tradingAssembly = TradingAssembly(
        tradingAPIAssembly: tradingAPIAssembly,
        appInfoProvider: dependencies.appInfoProvider,
        repositoriesAssembly: repositoriesAssembly,
        coreAssembly: coreAssembly,
        perpsSecurityConfig: PerpsSecurityConfigRepository.live(configuration: configurationAssembly.configuration)
    )
    private lazy var servicesAssembly = ServicesAssembly(
        repositoriesAssembly: repositoriesAssembly,
        storesAssembly: storesAssembly,
        apiAssembly: apiAssembly,
        tonkeeperAPIAssembly: tonkeeperApiAssembly,
        coreAssembly: coreAssembly,
        secureAssembly: secureAssembly,
        batteryAssembly: batteryAssembly,
        tronUSDTAssembly: tronUSDTAssembly,
        configurationAssembly: configurationAssembly,
        nativeSwapAPIAssembly: nativeSwapAPIAssembly,
        multichainSwapAPIAssembly: multichainSwapAPIAssembly,
        multichainRampAPIAssembly: multichainRampAPIAssembly,
        currenciesAPIAssembly: currenciesAPIAssembly,
        onRampAPIAssembly: onRampAPIAssembly,
        multichainAPIAssembly: multichainAPIAssembly,
        tradingAssembly: tradingAssembly,
        tonProofTokenService: tonProofTokenService,
        firebaseUserIdProvider: dependencies.firebaseUserIdProvider
    )
    private lazy var storesAssembly = StoresAssembly(
        apiAssembly: apiAssembly,
        coreAssembly: coreAssembly,
        repositoriesAssembly: repositoriesAssembly
    )
    private lazy var multichainAssembly: MultichainAssembly = MultichainAssembly(
        appInfoProvider: dependencies.appInfoProvider,
        mnemonicAccess: secureAssembly.mnemonicAccess,
        walletsStore: storesAssembly.walletsStore,
        multichainService: servicesAssembly.multichainService(),
        multichainClientAPI: multichainAPIAssembly.multichainAPI(),
        multichainAuthClientAPI: multichainAPIAssembly.multichainAuthAPI(),
        multichainSwapService: servicesAssembly.multichainSwapService(),
        pendingTransactionsService: servicesAssembly.pendingTransactionsService(),
        visibilityChangesController: servicesAssembly.visibilityChangesController,
        currencyStore: storesAssembly.currencyStore,
        configuration: configurationAssembly.configuration,
        keychainVault: coreAssembly.keychainVault,
        deviceAuthService: deviceAuthService,
        legacyBatteryMigrationController: legacyBatteryMigrationController,
        walletAuthTokenProvider: walletAuthTokenProvider
    )
    private lazy var walletConnectAssembly = WalletConnectAssembly(
        mnemonicAccess: secureAssembly.mnemonicAccess,
        coreAssembly: coreAssembly,
        walletsStore: storesAssembly.walletsStore,
        chainKitClient: multichainAssembly.chainKitClient,
        pendingTransactionsService: servicesAssembly.pendingTransactionsService(),
        configuration: configurationAssembly.configuration
    )
    private lazy var deeplinkParser = DeeplinkParser(
        walletConnectDeeplinkValidator: walletConnectAssembly.walletConnectDeeplinkValidator
    )
    private lazy var loadersAssembly = LoadersAssembly(
        servicesAssembly: servicesAssembly,
        storesAssembly: storesAssembly,
        tonkeeperAPIAssembly: tonkeeperApiAssembly,
        apiAssembly: apiAssembly,
        knownAccountsAssembly: knownAccountsAssembly,
        tronAssembly: tronUSDTAssembly,
        configurationAssembly: configurationAssembly,
        earnAssembly: earnAssembly,
        tkAppSettings: dependencies.tkAppSettings
    )
    private lazy var formattersAssembly = FormattersAssembly()
    private lazy var mappersAssembly = MappersAssembly(formattersAssembly: formattersAssembly)
    private var walletUpdateAssembly: WalletsUpdateAssembly {
        WalletsUpdateAssembly(
            storesAssembly: storesAssembly,
            servicesAssembly: servicesAssembly,
            repositoriesAssembly: repositoriesAssembly,
            formattersAssembly: formattersAssembly,
            secureAssembly: secureAssembly,
            configurationAssembly: configurationAssembly
        )
    }

    private lazy var rnAssembly = RNAssembly()
    private lazy var batteryAPIAssembly = BatteryAPIAssembly(configurationAssembly: configurationAssembly)
    private lazy var batteryAssembly: BatteryAssembly = BatteryAssembly(
        batteryAPIAssembly: batteryAPIAssembly,
        coreAssembly: coreAssembly,
        configurationAssembly: configurationAssembly,
        tonProofTokenService: tonProofTokenService,
        deviceAuth: deviceAuthService,
        walletAuthTokenProvider: walletAuthTokenProvider
    )

    private lazy var legacyBatteryMigrationController = makeLegacyBatteryMigrationController()

    private func makeLegacyBatteryMigrationController() -> LegacyBatteryMigrationController {
        let service = batteryAssembly.batteryService()
        let store = LegacyBatteryMigrationStore(keychainVault: coreAssembly.keychainVault, namespace: coreAssembly.seedProvider())
        let waiter = WalletMigrationBatteryIdleWaiter(
            batteryService: service,
            shouldRetryError: { !LegacyBatteryMigrationController.isAuthorizationError($0) }
        )
        let controller = LegacyBatteryMigrationController(dependencies: .init(
            load: store.load,
            save: store.save,
            wallets: { [walletsStore = storesAssembly.walletsStore] in
                await MainActor.run {
                    walletsStore.wallets.compactMap { try? JSONEncoder().encode($0) }
                }
            },
            balance: { data in
                let wallet = try JSONDecoder().decode(Wallet.self, from: data)
                return try await service.loadBatteryBalance(wallet: LegacyBatteryMigration.sourceWallet(from: wallet))
            },
            waitUntilIdle: { data in
                let wallet = try JSONDecoder().decode(Wallet.self, from: data)
                return try await waiter.wait(wallet: LegacyBatteryMigration.sourceWallet(from: wallet))
            },
            migrate: { data, proof in
                let wallet = try JSONDecoder().decode(Wallet.self, from: data)
                _ = try await service.migrateBattery(from: LegacyBatteryMigration.sourceWallet(from: wallet), to: wallet, proof: proof)
            },
            refreshBalance: { [weak self] data in
                await self?.refreshLegacyBatteryMigrationBalance(data)
            },
            authorizationAvailable: { [tonProofTokenService] data in
                guard let wallet = try? JSONDecoder().decode(Wallet.self, from: data),
                      let token = try? tonProofTokenService.getWalletToken(LegacyBatteryMigration.sourceWallet(from: wallet))
                else { return false }
                return !token.isEmpty
            },
            refreshAuthorization: { [tonProofTokenService, walletsStore = storesAssembly.walletsStore] data, privateKey in
                let wallet = try JSONDecoder().decode(Wallet.self, from: data)
                let source = LegacyBatteryMigration.sourceWallet(from: wallet)
                let sourceAddress = try source.address.toRaw()
                let token = try await tonProofTokenService.loadTokenFor(
                    pair: WalletPrivateKeyPair(wallet: source, privateKey: PrivateKey(data: privateKey)),
                    shouldKeepToken: {
                        await MainActor.run {
                            walletsStore.wallets.contains {
                                $0.network == .mainnet && $0.kind == .regular && !$0.isWalletTg
                                    && (try? $0.address.toRaw()) == sourceAddress
                            }
                        }
                    }
                )
                guard !token.isEmpty else { throw BatteryAuthorizationError.legacyProofUnavailable }
            }
        ))
        storesAssembly.walletsStore.addObserver(controller) { controller, event in
            switch event {
            case let .didDeleteWallet(wallet):
                let walletId = wallet.id
                Task { await controller.cancelAuthorization(walletId: walletId) }
            case .didDeleteAll:
                Task { await controller.cancelAuthorization() }
            case .didUpdateWalletMultichain:
                Task { await controller.resume() }
            default: break
            }
        }
        return controller
    }

    @MainActor
    private func prepareLegacyBatteryMigrations(_ mnemonics: [CoreMnemonicIdentifier: CoreMnemonic]) async {
        await legacyBatteryMigrationController.prepare(mnemonics: mnemonics)
    }

    @MainActor
    private func refreshLegacyBatteryMigrationBalance(_ data: Data) async {
        guard let snapshot = try? JSONDecoder().decode(Wallet.self, from: data),
              let walletId = snapshot.multichainWalletId,
              let wallet = storesAssembly.walletsStore.wallets.first(where: {
                  $0.kind == .regular && !$0.isWalletTg && $0.multichainWalletId == walletId
                      && LegacyBatteryMigration.identifier(wallet: $0, walletId: walletId)
                      == LegacyBatteryMigration.identifier(wallet: snapshot, walletId: walletId)
              })
        else { return }
        _ = await loadersAssembly.balanceLoader.reloadBalance(wallet: wallet, priority: .userInitiated)
    }

    private let dependencies: Dependencies

    public init(dependencies: Dependencies) {
        self.dependencies = dependencies
        let coreAssembly = CoreAssembly(
            cacheURL: dependencies.cacheURL,
            sharedCacheURL: dependencies.sharedCacheURL,
            appInfoProvider: dependencies.appInfoProvider,
            seedProvider: dependencies.seedProvider
        )
        self.coreAssembly = coreAssembly
        self.deviceTokenStore = DeviceTokenStore(keychainVault: coreAssembly.keychainVault)
    }
}

public extension Assembly {
    var totalAuthDeviceId: String? {
        deviceTokenStore.load()?.deviceId
    }

    /// Starts the device session refresh at launch, so the first request does not wait a round trip
    /// for it. A device without an id is skipped: only a real request may register one. The refresh
    /// can rotate the device, and handling a rotation builds graph parts that read feature flags once,
    /// so it starts only after `flagsLoad`.
    func startDeviceSession(after flagsLoad: @escaping () async -> Void) {
        let deviceAuth = deviceAuthService
        Task {
            await flagsLoad()
            guard await deviceAuth.isDeviceKnown() else { return }
            _ = try? await deviceAuth.session()
        }
    }

    func rootAssembly() -> RootAssembly {
        RootAssembly(
            appInfoProvider: dependencies.appInfoProvider,
            repositoriesAssembly: repositoriesAssembly,
            coreAssembly: coreAssembly,
            featureFlags: dependencies.featureFlags,
            servicesAssembly: servicesAssembly,
            storesAssembly: storesAssembly,
            formattersAssembly: formattersAssembly,
            mappersAssembly: mappersAssembly,
            walletsUpdateAssembly: walletUpdateAssembly,
            configurationAssembly: configurationAssembly,
            buySellAssembly: buySellAssembly,
            batteryAssembly: batteryAssembly,
            knownAccountsAssembly: knownAccountsAssembly,
            tonkeeperAPIAssembly: tonkeeperApiAssembly,
            apiAssembly: apiAssembly,
            loadersAssembly: loadersAssembly,
            backgroundUpdateAssembly: backgroundUpdateAssembly,
            rnAssembly: rnAssembly,
            secureAssembly: secureAssembly,
            transactionsManagementAssembly: transactionsManagementAssembly,
            tronUSDTAssembly: tronUSDTAssembly,
            multichainAssembly: multichainAssembly,
            tradingAssembly: tradingAssembly,
            deeplinkParser: deeplinkParser,
            walletConnectAssembly: walletConnectAssembly,
            earnAssembly: earnAssembly
        )
    }

    func widgetAssembly() -> WidgetAssembly {
        WidgetAssembly(
            repositoriesAssembly: repositoriesAssembly,
            coreAssembly: coreAssembly,
            servicesAssembly: servicesAssembly,
            storesAssembly: storesAssembly,
            formattersAssembly: formattersAssembly,
            walletsUpdateAssembly: walletUpdateAssembly,
            apiAssembly: apiAssembly,
            loadersAssembly: loadersAssembly,
            tradingAssembly: tradingAssembly
        )
    }

    /// The wallet screen reads these stores in its first frame, and their first read decodes the disk caches of every
    /// wallet. The stores are created on the caller's thread, because the assembly getters are not thread-safe;
    /// their state is read on a background queue, because `Store.state` is.
    func warmUpWalletScreenStores() {
        let stores: [() -> Void] = [
            { [store = storesAssembly.totalBalanceStore] in _ = store.state },
            { [store = storesAssembly.multichainPortfolioStore] in _ = store.state },
            { [store = earnAssembly.portfolioStore] in _ = store.state },
        ]
        DispatchQueue.global(qos: .userInitiated).async {
            stores.forEach { $0() }
            // The assembly holds some stores weakly; the screen takes them once the caller's run loop turn ends.
            DispatchQueue.main.async { withExtendedLifetime(stores) {} }
        }
    }
}

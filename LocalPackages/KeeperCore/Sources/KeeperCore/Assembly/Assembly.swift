import Foundation
import TKFeatureFlags

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
        configurationAssembly: configurationAssembly
    )
    public lazy var transactionsManagementAssembly = TransactionsManagementAssembly(
        coreAssembly: coreAssembly,
        scamAPIAssembly: scamAPIAssembly
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
    private lazy var scamAPIAssembly = ScamAPIAssembly(configurationAssembly: configurationAssembly)
    private lazy var nativeSwapAPIAssembly = NativeSwapAPIAssembly(configurationAssembly: configurationAssembly)
    private lazy var onRampAPIAssembly = OnRampAPIAssembly(
        configurationAssembly: configurationAssembly,
        appInfoProvider: dependencies.appInfoProvider,
        apiAssembly: apiAssembly
    )
    private lazy var multichainSwapAPIAssembly = MultichainSwapAPIAssembly(
        appInfoProvider: dependencies.appInfoProvider,
        apiAssembly: apiAssembly,
        tkAppSettings: dependencies.tkAppSettings
    )
    private lazy var multichainRampAPIAssembly = MultichainRampAPIAssembly(
        appInfoProvider: dependencies.appInfoProvider,
        apiAssembly: apiAssembly
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
    private lazy var tonProofTokenService: TonProofTokenService = TonProofTokenServiceImplementation(
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
        coreAssembly: coreAssembly
    )
    private lazy var servicesAssembly = ServicesAssembly(
        repositoriesAssembly: repositoriesAssembly,
        storesAssembly: storesAssembly,
        apiAssembly: apiAssembly,
        tonkeeperAPIAssembly: tonkeeperApiAssembly,
        scamAPIAssembly: scamAPIAssembly,
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
        walletAuthTokenProvider: walletAuthTokenProvider
    )
    private lazy var walletConnectAssembly = WalletConnectAssembly(
        mnemonicAccess: secureAssembly.mnemonicAccess,
        coreAssembly: coreAssembly,
        walletsStore: storesAssembly.walletsStore,
        chainKitClient: multichainAssembly.chainKitClient,
        pendingTransactionsService: servicesAssembly.pendingTransactionsService()
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
            walletConnectAssembly: walletConnectAssembly
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
            loadersAssembly: loadersAssembly
        )
    }
}

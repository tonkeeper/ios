import TKFeatureFlags

public final class RootAssembly {
    public let appInfoProvider: AppInfoProvider
    public let repositoriesAssembly: RepositoriesAssembly
    public let servicesAssembly: ServicesAssembly
    public let storesAssembly: StoresAssembly
    public let coreAssembly: CoreAssembly
    public let featureFlags: TKFeatureFlags
    public let formattersAssembly: FormattersAssembly
    public let mappersAssembly: MappersAssembly
    public let walletsUpdateAssembly: WalletsUpdateAssembly
    private let configurationAssembly: ConfigurationAssembly
    private let buySellAssembly: BuySellAssembly
    private let batteryAssembly: BatteryAssembly
    private let knownAccountsAssembly: KnownAccountsAssembly
    private let tonkeeperAPIAssembly: TonkeeperAPIAssembly
    private let apiAssembly: APIAssembly
    private let loadersAssembly: LoadersAssembly
    public let backgroundUpdateAssembly: BackgroundUpdateAssembly
    public let rnAssembly: RNAssembly
    public let secureAssembly: SecureAssembly
    public let transactionsManagementAssembly: TransactionsManagementAssembly
    public let tronUSDTAssembly: TronUSDTAssembly
    private let multichainAssembly: MultichainAssembly
    private let tradingAssembly: TradingAssembly
    private let deeplinkParser: DeeplinkParser
    private let walletConnectAssembly: WalletConnectAssembly

    init(
        appInfoProvider: AppInfoProvider,
        repositoriesAssembly: RepositoriesAssembly,
        coreAssembly: CoreAssembly,
        featureFlags: TKFeatureFlags,
        servicesAssembly: ServicesAssembly,
        storesAssembly: StoresAssembly,
        formattersAssembly: FormattersAssembly,
        mappersAssembly: MappersAssembly,
        walletsUpdateAssembly: WalletsUpdateAssembly,
        configurationAssembly: ConfigurationAssembly,
        buySellAssembly: BuySellAssembly,
        batteryAssembly: BatteryAssembly,
        knownAccountsAssembly: KnownAccountsAssembly,
        tonkeeperAPIAssembly: TonkeeperAPIAssembly,
        apiAssembly: APIAssembly,
        loadersAssembly: LoadersAssembly,
        backgroundUpdateAssembly: BackgroundUpdateAssembly,
        rnAssembly: RNAssembly,
        secureAssembly: SecureAssembly,
        transactionsManagementAssembly: TransactionsManagementAssembly,
        tronUSDTAssembly: TronUSDTAssembly,
        multichainAssembly: MultichainAssembly,
        tradingAssembly: TradingAssembly,
        deeplinkParser: DeeplinkParser,
        walletConnectAssembly: WalletConnectAssembly
    ) {
        self.appInfoProvider = appInfoProvider
        self.repositoriesAssembly = repositoriesAssembly
        self.coreAssembly = coreAssembly
        self.featureFlags = featureFlags
        self.servicesAssembly = servicesAssembly
        self.storesAssembly = storesAssembly
        self.formattersAssembly = formattersAssembly
        self.mappersAssembly = mappersAssembly
        self.walletsUpdateAssembly = walletsUpdateAssembly
        self.configurationAssembly = configurationAssembly
        self.buySellAssembly = buySellAssembly
        self.batteryAssembly = batteryAssembly
        self.knownAccountsAssembly = knownAccountsAssembly
        self.tonkeeperAPIAssembly = tonkeeperAPIAssembly
        self.apiAssembly = apiAssembly
        self.loadersAssembly = loadersAssembly
        self.backgroundUpdateAssembly = backgroundUpdateAssembly
        self.rnAssembly = rnAssembly
        self.secureAssembly = secureAssembly
        self.transactionsManagementAssembly = transactionsManagementAssembly
        self.tronUSDTAssembly = tronUSDTAssembly
        self.multichainAssembly = multichainAssembly
        self.tradingAssembly = tradingAssembly
        self.deeplinkParser = deeplinkParser
        self.walletConnectAssembly = walletConnectAssembly
    }

    private var _rootController: RootController?
    public func rootController() -> RootController {
        if let rootController = _rootController {
            return rootController
        } else {
            let rootController = RootController(
                configuration: configurationAssembly.configuration,
                deeplinkParser: deeplinkParser,
                keeperInfoRepository: repositoriesAssembly.keeperInfoRepository(),
                knownAccountsProvider: knownAccountsAssembly.knownAccountsProvider
            )
            self._rootController = rootController
            return rootController
        }
    }

    public func onboardingAssembly() -> OnboardingAssembly {
        OnboardingAssembly(
            walletsUpdateAssembly: walletsUpdateAssembly,
            storesAssembly: storesAssembly,
            deeplinkParser: deeplinkParser
        )
    }

    public func mainAssembly() -> MainAssembly {
        let tonConnectAssembly = TonConnectAssembly(
            repositoriesAssembly: repositoriesAssembly,
            servicesAssembly: servicesAssembly,
            storesAssembly: storesAssembly,
            apiAssembly: apiAssembly,
            coreAssembly: coreAssembly,
            formattersAssembly: formattersAssembly,
            secureAssembly: secureAssembly
        )
        return MainAssembly(
            appInfoProvider: appInfoProvider,
            repositoriesAssembly: repositoriesAssembly,
            walletUpdateAssembly: walletsUpdateAssembly,
            servicesAssembly: servicesAssembly,
            storesAssembly: storesAssembly,
            coreAssembly: coreAssembly,
            formattersAssembly: formattersAssembly,
            mappersAssembly: mappersAssembly,
            configurationAssembly: configurationAssembly,
            buySellAssembly: buySellAssembly,
            knownAccountsAssembly: knownAccountsAssembly,
            batteryAssembly: batteryAssembly,
            tonConnectAssembly: tonConnectAssembly,
            apiAssembly: apiAssembly,
            tonkeeperAPIAssembly: tonkeeperAPIAssembly,
            loadersAssembly: loadersAssembly,
            backgroundUpdateAssembly: backgroundUpdateAssembly,
            secureAssembly: secureAssembly,
            rnAssembly: rnAssembly,
            featureFlags: featureFlags,
            transactionsManagementAssembly: transactionsManagementAssembly,
            tronUSDTAssembly: tronUSDTAssembly,
            multichainAssembly: multichainAssembly,
            tradingAssembly: tradingAssembly,
            deeplinkParser: deeplinkParser,
            walletConnectAssembly: walletConnectAssembly
        )
    }
}

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
        tronUSDTAssembly: TronUSDTAssembly
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
    }

    private var _rootController: RootController?
    public func rootController() -> RootController {
        if let rootController = _rootController {
            return rootController
        } else {
            let rootController = RootController(
                configuration: configurationAssembly.configuration,
                deeplinkParser: DeeplinkParser(),
                keeperInfoRepository: repositoriesAssembly.keeperInfoRepository(),
                mnemonicsRepository: secureAssembly.mnemonicsRepository(),
                buySellProvider: buySellAssembly.buySellProvider,
                knownAccountsProvider: knownAccountsAssembly.knownAccountsProvider
            )
            self._rootController = rootController
            return rootController
        }
    }

    public func onboardingAssembly() -> OnboardingAssembly {
        OnboardingAssembly(
            walletsUpdateAssembly: walletsUpdateAssembly,
            storesAssembly: storesAssembly
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
        let tonWalletKitAssembly = TONWalletKitAssembly(
            storesAssembly: storesAssembly,
            tonConnectAssembly: tonConnectAssembly,
            apiAssembly: apiAssembly
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
            tonWalletKitAssembly: tonWalletKitAssembly,
            apiAssembly: apiAssembly,
            tonkeeperAPIAssembly: tonkeeperAPIAssembly,
            loadersAssembly: loadersAssembly,
            backgroundUpdateAssembly: backgroundUpdateAssembly,
            secureAssembly: secureAssembly,
            rnAssembly: rnAssembly,
            featureFlags: featureFlags,
            transactionsManagementAssembly: transactionsManagementAssembly,
            tronUSDTAssembly: tronUSDTAssembly
        )
    }
}

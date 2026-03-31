import Foundation

public final class ServicesAssembly {
    private let repositoriesAssembly: RepositoriesAssembly
    private let storesAssembly: StoresAssembly
    private let apiAssembly: APIAssembly
    private let tonkeeperAPIAssembly: TonkeeperAPIAssembly
    private let scamAPIAssembly: ScamAPIAssembly
    private let coreAssembly: CoreAssembly
    private let secureAssembly: SecureAssembly
    private let batteryAssembly: BatteryAssembly
    private let tronUSDTAssembly: TronUSDTAssembly
    private let configurationAssembly: ConfigurationAssembly
    private let nativeSwapAPIAssembly: NativeSwapAPIAssembly
    private let currenciesAPIAssembly: CurrenciesAPIAssembly
    private let onRampAPIAssembly: OnRampAPIAssembly

    init(
        repositoriesAssembly: RepositoriesAssembly,
        storesAssembly: StoresAssembly,
        apiAssembly: APIAssembly,
        tonkeeperAPIAssembly: TonkeeperAPIAssembly,
        scamAPIAssembly: ScamAPIAssembly,
        coreAssembly: CoreAssembly,
        secureAssembly: SecureAssembly,
        batteryAssembly: BatteryAssembly,
        tronUSDTAssembly: TronUSDTAssembly,
        configurationAssembly: ConfigurationAssembly,
        nativeSwapAPIAssembly: NativeSwapAPIAssembly,
        currenciesAPIAssembly: CurrenciesAPIAssembly,
        onRampAPIAssembly: OnRampAPIAssembly
    ) {
        self.repositoriesAssembly = repositoriesAssembly
        self.storesAssembly = storesAssembly
        self.apiAssembly = apiAssembly
        self.tonkeeperAPIAssembly = tonkeeperAPIAssembly
        self.scamAPIAssembly = scamAPIAssembly
        self.coreAssembly = coreAssembly
        self.secureAssembly = secureAssembly
        self.batteryAssembly = batteryAssembly
        self.tronUSDTAssembly = tronUSDTAssembly
        self.configurationAssembly = configurationAssembly
        self.nativeSwapAPIAssembly = nativeSwapAPIAssembly
        self.currenciesAPIAssembly = currenciesAPIAssembly
        self.onRampAPIAssembly = onRampAPIAssembly
    }

    public func walletsService() -> WalletsService {
        WalletsServiceImplementation(keeperInfoRepository: repositoriesAssembly.keeperInfoRepository())
    }

    public func balanceService() -> BalanceService {
        BalanceServiceImplementation(
            tonBalanceService: tonBalanceService(),
            jettonsBalanceService: jettonsBalanceService(),
            tronBalanceService: tronUSDTAssembly.balanceService(),
            batteryService: batteryAssembly.batteryService(),
            stackingService: stackingService(),
            tonProofTokenService: tonProofTokenService(),
            walletBalanceRepository: repositoriesAssembly.walletBalanceRepository()
        )
    }

    func tonBalanceService() -> TonBalanceService {
        TonBalanceServiceImplementation(apiProvider: apiAssembly.apiProvider)
    }

    func tronBalanceService() -> TronBalanceService {
        tronUSDTAssembly.balanceService()
    }

    func accountService() -> AccountService {
        AccountServiceImplementation(apiProvider: apiAssembly.apiProvider)
    }

    public func jettonService() -> JettonService {
        JettonServiceImplementation(apiProvider: apiAssembly.apiProvider)
    }

    func jettonsBalanceService() -> JettonBalanceService {
        JettonBalanceServiceImplementation(apiProvider: apiAssembly.apiProvider)
    }

    public func stackingService() -> StakingService {
        StakingServiceImplementation(
            apiProvider: apiAssembly.apiProvider
        )
    }

    func activeWalletsService() -> ActiveWalletsService {
        ActiveWalletsServiceImplementation(
            apiProvider: apiAssembly.apiProvider,
            jettonsBalanceService: jettonsBalanceService(),
            accountNFTService: accountNftService(),
            walletsService: walletsService()
        )
    }

    public func ratesService() -> RatesService {
        RatesServiceImplementation(
            api: apiAssembly.api,
            ratesRepository: repositoriesAssembly.ratesRepository()
        )
    }

    func currencyService() -> CurrencyService {
        CurrencyServiceImplementation(
            keeperInfoRepository: repositoriesAssembly.keeperInfoRepository()
        )
    }

    public func historyService() -> HistoryService {
        HistoryServiceImplementation(
            apiProvider: apiAssembly.apiProvider,
            repository: repositoriesAssembly.historyRepository()
        )
    }

    public func walletService() -> WalletService {
        WalletServiceImplementation(apiProvider: apiAssembly.apiProvider)
    }

    public func nftService() -> NFTService {
        NFTServiceImplementation(
            apiProvider: apiAssembly.apiProvider,
            scamAPI: scamAPIAssembly.api,
            nftRepository: repositoriesAssembly.nftRepository()
        )
    }

    public func blockchainService() -> BlockchainService {
        BlockchainServiceImplementation(
            apiProvider: apiAssembly.apiProvider
        )
    }

    public func accountNftService() -> AccountNFTService {
        AccountNFTServiceImplementation(
            apiProvider: apiAssembly.apiProvider,
            accountNFTRepository: repositoriesAssembly.accountsNftRepository(),
            nftRepository: repositoriesAssembly.nftRepository()
        )
    }

    func chartService() -> ChartService {
        ChartServiceImplementation(
            apiProvider: apiAssembly.apiProvider,
            repository: repositoriesAssembly.chartDataRepository()
        )
    }

    public func sendService() -> SendService {
        SendServiceImplementation(apiProvider: apiAssembly.apiProvider)
    }

    public func dnsService() -> DNSService {
        DNSServiceImplementation(apiProvider: apiAssembly.apiProvider)
    }

    public func dappFetchService() -> DappFetchService {
        DappFetchServiceImplementation(apiProvider: apiAssembly.apiProvider)
    }

    public func popularAppsService() -> PopularAppsService {
        PopularAppsServiceImplementation(
            api: tonkeeperAPIAssembly.api,
            popularAppsRepository: repositoriesAssembly.popularAppsRepository()
        )
    }

    public func encryptedCommentService() -> EncryptedCommentService {
        EncryptedCommentServiceImplementation(mnemonicsRepository: secureAssembly.mnemonicsRepository())
    }

    public func searchEngineService() -> SearchEngineServiceProtocol {
        SearchEngineService(session: .shared)
    }

    public func tonProofTokenService() -> TonProofTokenService {
        TonProofTokenServiceImplementation(
            keeperInfoRepository: repositoriesAssembly.keeperInfoRepository(),
            tonProofTokenRepository: repositoriesAssembly.tonProofTokenRepository(),
            mnemonicsRepository: secureAssembly.mnemonicsRepository(),
            api: apiAssembly.api
        )
    }

    public func notificationsService(
        walletNotificationsStore: WalletNotificationStore,
        tonConnectAppsStore: TonConnectAppsStore
    ) -> NotificationsService {
        NotificationsServiceImplementation(
            pushNotificationAPI: apiAssembly.pushNotificationsAPI,
            walletNotificationsStore: walletNotificationsStore,
            tonConnectAppsStore: tonConnectAppsStore,
            tonProofTokenService: tonProofTokenService()
        )
    }

    public func cookiesService() -> CookiesService {
        CookiesServiceImplementation(cookiesRepository: repositoriesAssembly.cookiesRepository())
    }

    public func nativeSwapService() -> NativeSwapService {
        NativeSwapServiceImplementation(nativeSwapAPI: nativeSwapAPIAssembly.nativeSwapAPI())
    }

    public func currenciesService() -> CurrenciesService {
        CurrenciesServiceImplementation(
            api: currenciesAPIAssembly.api,
            repository: repositoriesAssembly.currenciesRepository()
        )
    }

    public func onRampService() -> OnRampService {
        OnRampServiceImplementation(
            onRampAPI: onRampAPIAssembly.onRampAPI(),
            repository: repositoriesAssembly.onRampRepository()
        )
    }

    public private(set) lazy var tronUSDTFeesService: TronUsdtFeesService = TronUSDTFeesServiceImplementation(
        tronUsdtApi: tronUSDTAssembly.tronUsdtApi,
        walletsStore: storesAssembly.walletsStore,
        batteryCalculation: batteryAssembly.batteryCalculation,
        configuration: configurationAssembly.configuration
    )
}

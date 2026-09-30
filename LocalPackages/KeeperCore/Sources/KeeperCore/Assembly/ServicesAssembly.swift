import Foundation
import TKFeatureFlags

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
    private let multichainSwapAPIAssembly: MultichainSwapAPIAssembly
    private let multichainRampAPIAssembly: MultichainRampAPIAssembly
    private let currenciesAPIAssembly: CurrenciesAPIAssembly
    private let onRampAPIAssembly: OnRampAPIAssembly
    private let multichainAPIAssembly: MultichainAPIAssembly
    private let tradingAssembly: TradingAssembly
    private let sharedTonProofTokenService: TonProofTokenService
    private let firebaseUserIdProvider: () -> String?

    /// Stored rather than built per call: freshness and coalescing only work with one instance.
    private let ratesServiceInstance: RatesService

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
        multichainSwapAPIAssembly: MultichainSwapAPIAssembly,
        multichainRampAPIAssembly: MultichainRampAPIAssembly,
        currenciesAPIAssembly: CurrenciesAPIAssembly,
        onRampAPIAssembly: OnRampAPIAssembly,
        multichainAPIAssembly: MultichainAPIAssembly,
        tradingAssembly: TradingAssembly,
        tonProofTokenService: TonProofTokenService,
        firebaseUserIdProvider: @escaping () -> String?
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
        self.multichainSwapAPIAssembly = multichainSwapAPIAssembly
        self.multichainRampAPIAssembly = multichainRampAPIAssembly
        self.currenciesAPIAssembly = currenciesAPIAssembly
        self.onRampAPIAssembly = onRampAPIAssembly
        self.multichainAPIAssembly = multichainAPIAssembly
        self.tradingAssembly = tradingAssembly
        sharedTonProofTokenService = tonProofTokenService
        self.firebaseUserIdProvider = firebaseUserIdProvider
        ratesServiceInstance = RatesServiceImplementation(
            fetchRates: { [api = apiAssembly.api] jettons, currencies in
                try await api.getRates(currencies: currencies, jettons: jettons)
            },
            ratesRepository: repositoriesAssembly.ratesRepository()
        )
    }

    public func ratesService() -> RatesService {
        ratesServiceInstance
    }

    public func walletsService() -> WalletsService {
        WalletsServiceImplementation(keeperInfoRepository: repositoriesAssembly.keeperInfoRepository())
    }

    public func walletsResolveService() -> WalletsResolveService {
        WalletsResolveServiceImplementation(
            apiProvider: apiAssembly.apiProvider,
            firebaseUserIdProvider: firebaseUserIdProvider
        )
    }

    public func balanceService() -> BalanceService {
        BalanceServiceImplementation(
            tonBalanceService: tonBalanceService(),
            jettonsBalanceService: jettonsBalanceService(),
            tronBalanceService: tronUSDTAssembly.balanceService(),
            batteryService: batteryAssembly.batteryService(),
            stackingService: stackingService(),
            walletBalanceRepository: repositoriesAssembly.walletBalanceRepository()
        )
    }

    func tonBalanceService() -> TonBalanceService {
        TonBalanceServiceImplementation(apiProvider: apiAssembly.apiProvider)
    }

    func tronBalanceService() -> TronBalanceService {
        tronUSDTAssembly.balanceService()
    }

    public func tronUsdtApi() -> TronUSDTAPI {
        tronUSDTAssembly.tronUsdtApi
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

    func currencyService() -> CurrencyService {
        CurrencyServiceImplementation(
            keeperInfoRepository: repositoriesAssembly.keeperInfoRepository()
        )
    }

    public func historyService() -> HistoryService {
        HistoryServiceImplementation(
            apiProvider: apiAssembly.apiProvider,
            repository: repositoriesAssembly.historyRepository(),
            cacheNamespace: .allEvents
        )
    }

    public func tronUSDTHistoryService() -> HistoryService {
        HistoryServiceImplementation(
            apiProvider: apiAssembly.apiProvider,
            repository: repositoriesAssembly.historyRepository(),
            cacheNamespace: .tronUSDT
        )
    }

    public func tronTRXHistoryService() -> HistoryService {
        HistoryServiceImplementation(
            apiProvider: apiAssembly.apiProvider,
            repository: repositoriesAssembly.historyRepository(),
            cacheNamespace: .tronTRX
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
        chartService(
            repository: repositoriesAssembly.chartDataRepository()
        )
    }

    func chartService(
        repository: ChartDataRepository
    ) -> ChartService {
        ChartServiceImplementation(
            apiProvider: apiAssembly.apiProvider,
            tradingAPI: tradingAssembly.api,
            tradingRequestContextProvider: tradingAssembly.requestContextProvider,
            repository: repository
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
            popularAppsRepository: repositoriesAssembly.popularAppsRepository(),
            walletsStore: storesAssembly.walletsStore
        )
    }

    public func encryptedCommentService() -> EncryptedCommentService {
        EncryptedCommentServiceImplementation(
            mnemonicAccess: secureAssembly.mnemonicAccess
        )
    }

    public func searchEngineService() -> SearchEngineServiceProtocol {
        SearchEngineService(session: .shared)
    }

    public func tonProofTokenService() -> TonProofTokenService {
        sharedTonProofTokenService
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

    public func multichainSwapService() -> MultichainSwapService {
        MultichainSwapServiceImplementation(multichainSwapAPI: multichainSwapAPIAssembly.multichainSwapAPI())
    }

    public func multichainRampService() -> MultichainRampService {
        MultichainRampServiceImplementation(
            multichainRampAPI: multichainRampAPIAssembly.multichainRampAPI()
        )
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

    private lazy var multichainClientAPI = multichainAPIAssembly.multichainAPI()

    public private(set) lazy var visibilityChangesController = VisibilityChangesController(
        vault: coreAssembly.fileSystemVault(),
        writer: MultichainAssetVisibilityChangesClientWriter(
            multichainClientAPI: multichainClientAPI
        )
    )

    private lazy var pendingTransactionsServiceInstance: PendingTransactionsService = PendingTransactionsServiceImplementation(
        writer: MultichainPendingTransactionClientWriter(
            multichainClientAPI: multichainClientAPI
        )
    )

    private lazy var multichainServiceInstance: MultichainService = MultichainServiceImplementation(
        multichainClientAPI: multichainClientAPI,
        visibilityChangesController: visibilityChangesController,
        pendingTransactionsService: pendingTransactionsServiceInstance
    )

    public func multichainService() -> MultichainService {
        multichainServiceInstance
    }

    public func pendingTransactionsService() -> PendingTransactionsService {
        pendingTransactionsServiceInstance
    }

    public func walletMigrationService() -> WalletMigrationService {
        WalletMigrationServiceImplementation(
            apiProvider: apiAssembly.apiProvider,
            configuration: configurationAssembly.configuration,
            tonBalanceService: tonBalanceService(),
            tronBalanceService: tronUSDTAssembly.balanceService(),
            tronUsdtApi: tronUSDTAssembly.tronUsdtApi,
            ratesService: ratesService(),
            tonRatesStore: storesAssembly.tonRatesStore,
            batteryService: batteryAssembly.batteryService()
        )
    }

    public func walletMigrationExecutionService() -> WalletMigrationExecutionService {
        WalletMigrationExecutionServiceImplementation(
            sendService: sendService(),
            batteryService: batteryAssembly.batteryService(),
            tronUsdtApi: tronUSDTAssembly.tronUsdtApi,
            configuration: configurationAssembly.configuration
        )
    }

    public func tradingShelvesService() -> TradingShelvesService {
        tradingAssembly.shelvesService
    }

    public func assetsListService() -> TradingAssetsListService {
        tradingAssembly.assetsListService
    }

    public func assetDetailsService() -> TradingAssetDetailsService {
        tradingAssembly.assetDetailsService
    }

    public func tradingFavoriteAssetsService() -> TradingFavoriteAssetsService {
        tradingAssembly.favoriteAssetsService
    }

    public private(set) lazy var tronUSDTFeesService: TronUsdtFeesService = TronUSDTFeesServiceImplementation(
        tronUsdtApi: tronUSDTAssembly.tronUsdtApi,
        walletsStore: storesAssembly.walletsStore,
        batteryCalculation: batteryAssembly.batteryCalculation,
        configuration: configurationAssembly.configuration
    )
}

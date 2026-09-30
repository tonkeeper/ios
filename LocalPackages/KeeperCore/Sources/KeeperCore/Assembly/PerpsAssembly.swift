import ChainKit
import Foundation
import TKKeychain

public final class PerpsAssembly {
    private let configurationAssembly: ConfigurationAssembly
    private let tradingAPI: TradingAPI
    private let tradingRequestContextProvider: TradingRequestContextProvider
    private let mnemonicAccess: MnemonicAccess
    private let keychainVault: TKKeychainVault
    private let apiAssembly: APIAssembly
    private let appInfoProvider: AppInfoProvider
    private let walletAuth: () -> MultichainWalletAuthDependencies
    private let chainKitClient: CryptoKitClient

    /// One session per timeout profile, shared by every client on it. Not `lazy`: `lazy var` is not
    /// atomic and these are read from concurrent callers.
    private let urlSession: URLSession

    /// Hermes idles between ticks, so minutes rather than the ordinary 60 s; both clients on it ping
    /// every 120 s, well inside this. `.infinity` here was undefined behaviour in CFNetwork's timer.
    private let hermesUrlSession: URLSession
    private let perpsAPI: PerpsAPI

    init(
        configurationAssembly: ConfigurationAssembly,
        tradingAPI: TradingAPI,
        tradingRequestContextProvider: TradingRequestContextProvider,
        mnemonicAccess: MnemonicAccess,
        keychainVault: TKKeychainVault,
        apiAssembly: APIAssembly,
        appInfoProvider: AppInfoProvider,
        walletAuth: @escaping () -> MultichainWalletAuthDependencies,
        chainKitClient: CryptoKitClient
    ) {
        self.configurationAssembly = configurationAssembly
        self.tradingAPI = tradingAPI
        self.tradingRequestContextProvider = tradingRequestContextProvider
        self.mnemonicAccess = mnemonicAccess
        self.keychainVault = keychainVault
        self.apiAssembly = apiAssembly
        self.appInfoProvider = appInfoProvider
        self.walletAuth = walletAuth
        self.chainKitClient = chainKitClient

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 60
        urlSession = URLSession(configuration: configuration)

        let hermesConfiguration = URLSessionConfiguration.default
        hermesConfiguration.timeoutIntervalForRequest = 300
        hermesUrlSession = URLSession(configuration: hermesConfiguration)

        perpsAPI = PerpsAPIImplementation { [apiAssembly, appInfoProvider, walletAuth, configurationAssembly] walletId in
            let dependencies = walletAuth()
            let session = try? await dependencies.deviceAuth.session()
            let accessToken = session?.accessToken ?? ""
            return try apiAssembly.walletAuthPerpsAPIClient(
                hostURL: await configurationAssembly.configuration.multichainHost(network: .mainnet),
                deviceJWT: accessToken,
                walletId: walletId,
                walletAuthToken: await dependencies.walletAuthTokenProvider.token(
                    walletId: walletId,
                    accessToken: accessToken
                ),
                recovery: dependencies,
                userAgent: appInfoProvider.userAgent
            )
        }
    }

    private lazy var kandelabr: KandelabrAPI = KandelabrAPIImplementation(
        hostProvider: KandelabrAPIHostProvider(
            configuration: configurationAssembly.configuration
        ),
        urlSession: urlSession
    )

    private lazy var hermes: HermesCandleStreaming = HermesCandleClient(
        hostProvider: KandelabrAPIHostProvider(
            configuration: configurationAssembly.configuration
        ),
        urlSession: hermesUrlSession
    )

    private lazy var markPrices: HermesMarkPricesStreaming = HermesMarkPricesClient(
        hostProvider: KandelabrAPIHostProvider(
            configuration: configurationAssembly.configuration
        ),
        urlSession: hermesUrlSession
    )

    public private(set) lazy var marketsRepository = PerpsMarketsRepository(
        api: tradingAPI,
        requestContextProvider: tradingRequestContextProvider
    )

    public private(set) lazy var marketsStore = PerpsMarketsStore(
        repository: marketsRepository,
        pricesClient: markPrices
    )

    public private(set) lazy var chartService: PerpsChartProviding = PerpsChartService(
        kandelabr: kandelabr,
        hermes: hermes,
        marketsRepository: marketsRepository
    )

    public func makeMarketDetailsStore() -> PerpsMarketDetailsStore {
        PerpsMarketDetailsStore(service: marketDetailsService)
    }

    public func makeWalletScope(for wallet: Wallet) -> PerpsWalletScope {
        PerpsWalletScope(
            wallet: wallet,
            accountService: accountService,
            perpsAPI: perpsAPI,
            // Live only: a cached catalog price carries no observation time, and the
            // planner would stamp it as observed now and prefer it over the mark price
            // that came with the trading screen it is planning against.
            markPriceProvider: { [marketsStore] marketId in
                await marketsStore.livePrice(marketId: marketId)
            },
            marketProvider: { [marketsRepository] marketId in
                await marketsRepository.market(marketId: marketId)
            }
        )
    }

    private lazy var marketDetailsService = PerpsMarketDetailsService(repository: marketsRepository)
    private lazy var accountService = PerpsAccountService(
        mnemonicAccess: mnemonicAccess,
        keychainVault: keychainVault,
        perpsAPI: perpsAPI,
        bindSigner: PerpsAccountBindSigner(client: chainKitClient)
    )

    func clearLighterCredentials(wallet: Wallet) {
        accountService.clearCredentials(wallet: wallet)
    }
}

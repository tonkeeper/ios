import Foundation
import TKKeychain

public final class PerpsAssembly {
    private let configurationAssembly: ConfigurationAssembly
    private let tradingAPI: TradingAPI
    private let tradingRequestContextProvider: TradingRequestContextProvider
    private let mnemonicAccess: MnemonicAccess
    private let keychainVault: TKKeychainVault

    /// One session per timeout profile, shared by every client on it. Not `lazy`: `lazy var` is not
    /// atomic and these are read from concurrent callers.
    private let urlSession: URLSession

    /// Hermes idles between ticks, so minutes rather than the ordinary 60 s; both clients on it ping
    /// every 120 s, well inside this. `.infinity` here was undefined behaviour in CFNetwork's timer.
    private let hermesUrlSession: URLSession

    init(
        configurationAssembly: ConfigurationAssembly,
        tradingAPI: TradingAPI,
        tradingRequestContextProvider: TradingRequestContextProvider,
        mnemonicAccess: MnemonicAccess,
        keychainVault: TKKeychainVault
    ) {
        self.configurationAssembly = configurationAssembly
        self.tradingAPI = tradingAPI
        self.tradingRequestContextProvider = tradingRequestContextProvider
        self.mnemonicAccess = mnemonicAccess
        self.keychainVault = keychainVault

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 60
        urlSession = URLSession(configuration: configuration)

        let hermesConfiguration = URLSessionConfiguration.default
        hermesConfiguration.timeoutIntervalForRequest = 300
        hermesUrlSession = URLSession(configuration: hermesConfiguration)
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
            activationService: activationService,
            markPriceProvider: { [marketsStore] marketId in
                await marketsStore.price(marketId: marketId)
            },
            marketProvider: { [marketsRepository] marketId in
                await marketsRepository.market(marketId: marketId)
            }
        )
    }

    private lazy var marketDetailsService = PerpsMarketDetailsService(repository: marketsRepository)
    private lazy var activationService = LighterActivationService(
        mnemonicAccess: mnemonicAccess,
        keychainVault: keychainVault,
        configuration: configurationAssembly.configuration
    )

    func clearLighterCredentials(wallet: Wallet) {
        activationService.clearCredentials(wallet: wallet)
    }
}

import ChainKit
import Foundation
import PerpsModels
import TKKeychain

public final class PerpsAssembly {
    public let marketsRepository: PerpsMarketsRepository
    public let marketsStore: PerpsMarketsStore
    public let chartService: PerpsChartProviding
    private let perpsAPI: PerpsAPI
    private let marketDetailsService: PerpsMarketDetailsService
    private let accountService: PerpsAccountService
    private let multichainService: () -> MultichainService

    init(
        configurationAssembly: ConfigurationAssembly,
        tradingAPI: TradingAPI,
        tradingRequestContextProvider: TradingRequestContextProvider,
        mnemonicAccess: MnemonicAccess,
        keychainVault: TKKeychainVault,
        apiAssembly: APIAssembly,
        appInfoProvider: AppInfoProvider,
        walletAuth: @escaping () -> MultichainWalletAuthDependencies,
        chainKitClient: CryptoKitClient,
        multichainService: @escaping () -> MultichainService
    ) {
        self.multichainService = multichainService
        // One session per timeout profile, shared by every client on it.
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 60
        let urlSession = URLSession(configuration: configuration)

        // Hermes idles between ticks, so minutes rather than the ordinary 60 s; the shared socket on it pings
        // every 120 s, well inside this. `.infinity` here was undefined behaviour in CFNetwork's timer.
        let hermesConfiguration = URLSessionConfiguration.default
        hermesConfiguration.timeoutIntervalForRequest = 300
        let hermesUrlSession = URLSession(configuration: hermesConfiguration)

        let kandelabrHost = KandelabrAPIHostProvider(configuration: configurationAssembly.configuration)
        let hermes = HermesSocketHub(hostProvider: kandelabrHost, urlSession: hermesUrlSession)

        let perpsAPI = PerpsAPIImplementation { [apiAssembly, appInfoProvider, walletAuth, configurationAssembly] walletId in
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
        self.perpsAPI = perpsAPI

        let marketsRepository = PerpsMarketsRepository(
            api: tradingAPI,
            requestContextProvider: tradingRequestContextProvider
        )
        self.marketsRepository = marketsRepository
        marketsStore = PerpsMarketsStore(
            repository: marketsRepository,
            pricesClient: HermesMarkPricesClient(hub: hermes)
        )
        chartService = PerpsChartService(
            kandelabr: KandelabrAPIImplementation(hostProvider: kandelabrHost, urlSession: urlSession),
            hermes: HermesCandleClient(hub: hermes),
            marketsRepository: marketsRepository
        )
        marketDetailsService = PerpsMarketDetailsService(repository: marketsRepository)
        accountService = PerpsAccountService(
            mnemonicAccess: mnemonicAccess,
            keychainVault: keychainVault,
            perpsAPI: perpsAPI,
            bindSigner: PerpsAccountBindSigner(client: chainKitClient),
            walletAuthTokenProvider: walletAuth().walletAuthTokenProvider,
            chainKitClient: chainKitClient
        )
    }

    public func makeMarketDetailsStore() -> PerpsMarketDetailsStore {
        PerpsMarketDetailsStore(service: marketDetailsService)
    }

    /// The wallet's perps scope, and with it one account store per wallet: every screen
    /// reading positions shares the same poll and the same answer. Held weakly, so a
    /// wallet nobody is showing stops polling and recovering instead of lingering.
    public func walletScope(for wallet: Wallet) -> PerpsWalletScope {
        walletScopeLock.withLock {
            if let scope = walletScopes[wallet.id]?.value {
                return scope
            }
            let scope = PerpsWalletScope(
                wallet: wallet,
                accountService: accountService,
                perpsAPI: perpsAPI,
                multichainService: multichainService(),
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
            walletScopes = walletScopes.filter { $0.value.value != nil }
            walletScopes[wallet.id] = Weak(value: scope)
            return scope
        }
    }

    private let walletScopeLock = NSLock()
    private var walletScopes = [String: Weak<PerpsWalletScope>]()

    func clearLighterCredentials(wallet: Wallet) {
        accountService.clearCredentials(wallet: wallet)
    }
}

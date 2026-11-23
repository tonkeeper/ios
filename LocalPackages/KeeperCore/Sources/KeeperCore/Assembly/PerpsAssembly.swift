import ChainKit
import Foundation
import PerpsModels
import TKFeatureFlags
import TKKeychain

public final class PerpsAssembly {
    public let marketsRepository: PerpsMarketsRepository
    public let marketsStore: PerpsMarketsStore
    public let chartService: PerpsChartProviding
    private let perpsAPI: PerpsAPI
    private let marketDetailsService: PerpsMarketDetailsService
    private let accountService: PerpsAccountService
    private let multichainService: () -> MultichainService
    private let makeHistoryEvents: (Wallet) -> PerpsHistoryEvents
    private let perpsSignals: @Sendable (_ walletId: String) -> AsyncStream<PerpsRealtimeSignal>
    private let isRealtimeEnabled: @Sendable () -> Bool
    private let appConfiguration: Configuration
    private let unlistedPositions: PerpsUnlistedPositionsReport
    private let securityConfig: PerpsSecurityConfigRepository

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
        multichainService: @escaping () -> MultichainService,
        historyEvents: @escaping (Wallet) -> PerpsHistoryEvents,
        swapFeeMethods: @escaping () -> MultichainSwapFeeMethodResolver?,
        perpsSignals: @escaping @Sendable (_ walletId: String) -> AsyncStream<PerpsRealtimeSignal>
    ) {
        self.multichainService = multichainService
        makeHistoryEvents = historyEvents
        self.perpsSignals = perpsSignals
        appConfiguration = configurationAssembly.configuration
        isRealtimeEnabled = { [appConfiguration = configurationAssembly.configuration] in
            appConfiguration.featureEnabled(.perpsRealtimeEnabled)
        }
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
        let deviceAuth = walletAuth().deviceAuth
        let hermes = HermesSocketHub(
            hostProvider: kandelabrHost,
            urlSession: hermesUrlSession,
            deviceAuth: deviceAuth
        )

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

        let securityConfig = PerpsSecurityConfigRepository.live(configuration: configurationAssembly.configuration)
        self.securityConfig = securityConfig
        unlistedPositions = PerpsUnlistedPositionsReport(signedSymbols: { await securityConfig.verified()?.signedSymbols })
        let marketsRepository = PerpsMarketsRepository(
            api: tradingAPI,
            requestContextProvider: tradingRequestContextProvider,
            signedSymbols: { await securityConfig.verified()?.signedSymbols }
        )
        self.marketsRepository = marketsRepository
        marketsStore = PerpsMarketsStore(
            repository: marketsRepository,
            pricesClient: HermesMarkPricesClient(hub: hermes)
        )
        chartService = PerpsChartService(
            kandelabr: KandelabrAPIImplementation(
                hostProvider: kandelabrHost,
                urlSession: urlSession,
                deviceAuth: deviceAuth
            ),
            hermes: HermesCandleClient(hub: hermes),
            marketsRepository: marketsRepository
        )
        marketDetailsService = PerpsMarketDetailsService(repository: marketsRepository)
        accountService = PerpsAccountService(
            mnemonicAccess: mnemonicAccess,
            keychainVault: keychainVault,
            perpsAPI: perpsAPI,
            submitLanes: PerpsSubmitLanes(api: perpsAPI),
            bindSigner: PerpsAccountBindSigner(client: chainKitClient),
            walletAuthTokenProvider: walletAuth().walletAuthTokenProvider,
            chainKitClient: chainKitClient,
            depositGate: OperationGate(configuration: configurationAssembly.configuration, validatingWith: chainKitClient),
            swapFeeMethods: swapFeeMethods,
            securityConfig: securityConfig
        )
    }

    public func marketId(symbol: String) -> Int64? {
        securityConfig.verifiedNow()?.marketId(symbol: symbol)
    }

    public var access: PerpsAccess {
        appConfiguration.perpsAccess
    }

    public func reloadAccess() async -> PerpsAccess {
        _ = await appConfiguration.reloadConfigurations()
        return access
    }

    public func observeAccess<Observer: AnyObject>(_ observer: Observer, onChange: @escaping @Sendable (Observer) -> Void) {
        appConfiguration.addUpdateObserver(observer, closure: onChange)
    }

    public func historyEvents(for wallet: Wallet) -> PerpsHistoryEvents {
        makeHistoryEvents(wallet)
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
                historyEvents: makeHistoryEvents(wallet),
                // Live only: a cached catalog price carries no observation time, and the
                // planner would stamp it as observed now and prefer it over the mark price
                // that came with the trading screen it is planning against.
                markPriceProvider: { [marketsStore] marketId in
                    await marketsStore.livePrice(marketId: marketId)
                },
                marketProvider: { [marketsRepository] marketId in
                    await marketsRepository.market(marketId: marketId)
                },
                markPrices: { [marketsStore] marketIds in
                    marketsStore.livePrices(of: marketIds)
                },
                perpsSignals: perpsSignals,
                isRealtimeEnabled: isRealtimeEnabled,
                unlistedPositions: unlistedPositions
            )
            walletScopes = walletScopes.filter { $0.value.value != nil }
            walletScopes[wallet.id] = Weak(value: scope)
            return scope
        }
    }

    /// Positions poll only for screens, so the background pauses them. A scope created in the
    /// background starts unpaused, but no screen can subscribe to it before the foreground.
    public func setForeground(_ isForeground: Bool) {
        let scopes = walletScopeLock.withLock { walletScopes.values.compactMap(\.value) }
        for scope in scopes {
            scope.accountStore.setForeground(isForeground)
        }
    }

    private let walletScopeLock = NSLock()
    private var walletScopes = [String: Weak<PerpsWalletScope>]()

    func clearLighterCredentials(wallet: Wallet) {
        accountService.clearCredentials(wallet: wallet)
    }
}

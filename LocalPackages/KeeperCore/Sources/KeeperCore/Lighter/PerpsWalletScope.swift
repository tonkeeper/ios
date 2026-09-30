public final class PerpsWalletScope {
    public let wallet: Wallet
    public let accountService: PerpsAccountService

    private lazy var tkTradingService = PerpsTkTradingService(
        accountService: accountService,
        wallet: wallet,
        perpsAPI: perpsAPI,
        markPriceProvider: markPriceProvider,
        marketProvider: marketProvider
    )

    public private(set) lazy var tradingService: PerpsTradingService = tkTradingService

    public private(set) lazy var accountStore = PerpsAccountStore(
        service: PerpsTkAccountReading(
            api: perpsAPI
        ),
        wallet: wallet,
        recoverOperations: { [tkTradingService] in
            await tkTradingService.recoverInterruptedOperations()
        }
    )

    private let markPriceProvider: @Sendable (Int64) async -> Double?
    private let marketProvider: @Sendable (Int64) async -> PerpsMarketMetadata?
    private let perpsAPI: PerpsAPI

    init(
        wallet: Wallet,
        accountService: PerpsAccountService,
        perpsAPI: PerpsAPI,
        markPriceProvider: @escaping @Sendable (Int64) async -> Double?,
        marketProvider: @escaping @Sendable (Int64) async -> PerpsMarketMetadata?
    ) {
        self.wallet = wallet
        self.accountService = accountService
        self.perpsAPI = perpsAPI
        self.markPriceProvider = markPriceProvider
        self.marketProvider = marketProvider
    }
}

public final class PerpsWalletScope {
    public let wallet: Wallet
    public let activationService: LighterActivationService

    private lazy var lighterTradingService = LighterPerpsTradingService(
        activationService: activationService,
        wallet: wallet,
        markPriceProvider: markPriceProvider,
        marketProvider: marketProvider
    )

    public private(set) lazy var tradingService: PerpsTradingService = lighterTradingService

    public private(set) lazy var accountStore = PerpsAccountStore(
        service: activationService,
        wallet: wallet,
        recoverOperations: { [lighterTradingService] in
            await lighterTradingService.recoverInterruptedOperations()
        }
    )

    private let markPriceProvider: @Sendable (Int64) async -> Double?
    private let marketProvider: @Sendable (Int64) async -> PerpsMarketMetadata?

    init(
        wallet: Wallet,
        activationService: LighterActivationService,
        markPriceProvider: @escaping @Sendable (Int64) async -> Double?,
        marketProvider: @escaping @Sendable (Int64) async -> PerpsMarketMetadata?
    ) {
        self.wallet = wallet
        self.activationService = activationService
        self.markPriceProvider = markPriceProvider
        self.marketProvider = marketProvider
    }
}

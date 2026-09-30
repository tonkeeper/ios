import BigInt
import Foundation
import TKFeatureFlags
import TonSwift
import URKit

public final class MainAssembly {
    public let appInfoProvider: AppInfoProvider
    public let repositoriesAssembly: RepositoriesAssembly
    public let walletUpdateAssembly: WalletsUpdateAssembly
    public let servicesAssembly: ServicesAssembly
    public let storesAssembly: StoresAssembly
    public let coreAssembly: CoreAssembly
    public let formattersAssembly: FormattersAssembly
    public let mappersAssembly: MappersAssembly
    public let configurationAssembly: ConfigurationAssembly
    public let buySellAssembly: BuySellAssembly
    public let knownAccountsAssembly: KnownAccountsAssembly
    public let batteryAssembly: BatteryAssembly
    public let tonConnectAssembly: TonConnectAssembly
    public let loadersAssembly: LoadersAssembly
    public let backgroundUpdateAssembly: BackgroundUpdateAssembly
    public let apiAssembly: APIAssembly
    public let tonkeeperAPIAssembly: TonkeeperAPIAssembly
    public let rnAssembly: RNAssembly
    public let secureAssembly: SecureAssembly
    public let transferAssembly: TransferAssembly
    public let featureFlags: TKFeatureFlags
    public let transactionsManagementAssembly: TransactionsManagementAssembly
    public let tronUSDTAssembly: TronUSDTAssembly
    public let multichainAssembly: MultichainAssembly
    public let deeplinkParser: DeeplinkParser
    public let walletConnectAssembly: WalletConnectAssembly
    let tradingAssembly: TradingAssembly

    init(
        appInfoProvider: AppInfoProvider,
        repositoriesAssembly: RepositoriesAssembly,
        walletUpdateAssembly: WalletsUpdateAssembly,
        servicesAssembly: ServicesAssembly,
        storesAssembly: StoresAssembly,
        coreAssembly: CoreAssembly,
        formattersAssembly: FormattersAssembly,
        mappersAssembly: MappersAssembly,
        configurationAssembly: ConfigurationAssembly,
        buySellAssembly: BuySellAssembly,
        knownAccountsAssembly: KnownAccountsAssembly,
        batteryAssembly: BatteryAssembly,
        tonConnectAssembly: TonConnectAssembly,
        apiAssembly: APIAssembly,
        tonkeeperAPIAssembly: TonkeeperAPIAssembly,
        loadersAssembly: LoadersAssembly,
        backgroundUpdateAssembly: BackgroundUpdateAssembly,
        secureAssembly: SecureAssembly,
        rnAssembly: RNAssembly,
        featureFlags: TKFeatureFlags,
        transactionsManagementAssembly: TransactionsManagementAssembly,
        tronUSDTAssembly: TronUSDTAssembly,
        multichainAssembly: MultichainAssembly,
        tradingAssembly: TradingAssembly,
        deeplinkParser: DeeplinkParser,
        walletConnectAssembly: WalletConnectAssembly
    ) {
        self.appInfoProvider = appInfoProvider
        self.repositoriesAssembly = repositoriesAssembly
        self.walletUpdateAssembly = walletUpdateAssembly
        self.servicesAssembly = servicesAssembly
        self.storesAssembly = storesAssembly
        self.coreAssembly = coreAssembly
        self.formattersAssembly = formattersAssembly
        self.mappersAssembly = mappersAssembly
        self.configurationAssembly = configurationAssembly
        self.buySellAssembly = buySellAssembly
        self.knownAccountsAssembly = knownAccountsAssembly
        self.batteryAssembly = batteryAssembly
        self.tonConnectAssembly = tonConnectAssembly
        self.apiAssembly = apiAssembly
        self.tonkeeperAPIAssembly = tonkeeperAPIAssembly
        self.loadersAssembly = loadersAssembly
        self.backgroundUpdateAssembly = backgroundUpdateAssembly
        self.secureAssembly = secureAssembly
        self.rnAssembly = rnAssembly
        self.transferAssembly = TransferAssembly(
            servicesAssembly: servicesAssembly,
            batteryAssembly: batteryAssembly,
            configurationAssembly: configurationAssembly,
            repositoriesAssembly: repositoriesAssembly,
            storesAssembly: storesAssembly
        )
        self.featureFlags = featureFlags
        self.transactionsManagementAssembly = transactionsManagementAssembly
        self.tronUSDTAssembly = tronUSDTAssembly
        self.multichainAssembly = multichainAssembly
        self.tradingAssembly = tradingAssembly
        self.deeplinkParser = deeplinkParser
        self.walletConnectAssembly = walletConnectAssembly
    }

    public func scannerAssembly() -> ScannerAssembly {
        ScannerAssembly(deeplinkParser: deeplinkParser)
    }

    public var mnemonicAccess: MnemonicAccess {
        secureAssembly.mnemonicAccess
    }

    public private(set) lazy var perpsAssembly = PerpsAssembly(
        configurationAssembly: configurationAssembly,
        tradingAPI: tradingAssembly.api,
        tradingRequestContextProvider: tradingAssembly.requestContextProvider,
        mnemonicAccess: secureAssembly.mnemonicAccess,
        keychainVault: coreAssembly.keychainVault,
        apiAssembly: apiAssembly,
        appInfoProvider: appInfoProvider,
        walletAuth: { [multichainAssembly] in
            multichainAssembly.walletAuthDependencies()
        },
        chainKitClient: multichainAssembly.chainKitClient
    )

    public var perpsChartService: PerpsChartProviding {
        perpsAssembly.chartService
    }

    public var visibilityChangesController: VisibilityChangesController {
        servicesAssembly.visibilityChangesController
    }

    /// Lives here rather than in `MultichainAssembly` because a relayed fee method needs both
    /// halves of the graph: the ChainKit swap pipeline and the TON transfer/battery services.
    public private(set) lazy var multichainSwapExecutionService: MultichainSwapExecutionService =
        MultichainSwapExecutionServiceImplementation(
            swapService: servicesAssembly.multichainSwapService(),
            swapPipeline: multichainAssembly.chainKitSwapPipeline,
            pendingTransactionsService: servicesAssembly.pendingTransactionsService(),
            feeMethodResolver: MultichainSwapFeeMethodResolver(
                engines: [
                    MultichainSwapTonBatteryFeeEngine(
                        transferService: transferAssembly.transferService(),
                        balanceService: servicesAssembly.balanceService(),
                        batteryService: batteryAssembly.batteryService(),
                        batteryCalculation: batteryAssembly.batteryCalculation,
                        configuration: configurationAssembly.configuration,
                        chainKitService: multichainAssembly.chainKitService,
                        mnemonicAccess: secureAssembly.mnemonicAccess
                    ),
                    MultichainSwapTronRelayedFeeEngine(
                        tronUsdtApi: tronUSDTAssembly.tronUsdtApi,
                        sendService: servicesAssembly.sendService(),
                        balanceService: servicesAssembly.balanceService(),
                        batteryService: batteryAssembly.batteryService(),
                        batteryCalculation: batteryAssembly.batteryCalculation,
                        configuration: configurationAssembly.configuration,
                        chainKitService: multichainAssembly.chainKitService,
                        mnemonicAccess: secureAssembly.mnemonicAccess
                    ),
                ]
            )
        )

    public func mainController() -> MainController {
        MainController(
            backgroundUpdate: backgroundUpdateAssembly.backgroundUpdate,
            tonConnectEventsStore: tonConnectAssembly.tonConnectEventsStore,
            tonConnectService: tonConnectAssembly.tonConnectService(),
            deeplinkParser: deeplinkParser,
            walletsStore: storesAssembly.walletsStore,
            balanceLoader: loadersAssembly.balanceLoader,
            internalNotificationsLoader: loadersAssembly.internalNotificationsLoader,
            homeBannersLoader: loadersAssembly.homeBannersLoader,
            walletInfoLoader: loadersAssembly.walletInfoLoader,
            tronUSDTFeesService: servicesAssembly.tronUSDTFeesService,
            multichainRealtimeManager: multichainAssembly.realtimeManager
        )
    }

    public var walletDeleteController: WalletDeleteController {
        WalletDeleteController(
            walletStore: storesAssembly.walletsStore,
            keeperInfoStore: storesAssembly.keeperInfoStore,
            mnemonicAccess: mnemonicAccess,
            securityStore: storesAssembly.securityStore,
            walletAuthTokenProvider: multichainAssembly.walletAuthTokenProvider,
            lighterCredentialsCleanup: { [perpsAssembly] wallet in
                perpsAssembly.clearLighterCredentials(wallet: wallet)
            },
            multichainBindingCleanup: { [multichainAssembly, storesAssembly] wallets in
                // Wallets differing only in TON contract version share a multichain walletId,
                // so a binding is only stale once no local wallet maps to it.
                let remaining = Set(storesAssembly.walletsStore.wallets.compactMap { $0.multichainWalletState?.walletId })
                let walletIds = Set(wallets.compactMap { $0.multichainWalletState?.walletId })
                    .subtracting(remaining)
                guard !walletIds.isEmpty else { return }
                multichainAssembly.multichainAuthService
                    .enqueueUnregisterWallets(walletIds: Array(walletIds))
            }
        )
    }

    public func chartV2Controller(token: Token, wallet: Wallet) -> ChartV2Controller {
        chartV2Controller(
            asset: ChartAsset(token: token, wallet: wallet),
            wallet: wallet
        )
    }

    public func chartV2Controller(assetId: String, wallet: Wallet) -> ChartV2Controller? {
        ChartAsset(assetId: assetId, wallet: wallet).map {
            chartV2Controller(asset: $0, wallet: wallet)
        }
    }

    private func chartV2Controller(
        asset: ChartAsset,
        wallet: Wallet
    ) -> ChartV2Controller {
        ChartV2Controller(
            asset: asset,
            network: wallet.network,
            chartService: servicesAssembly.chartService(),
            currencyStore: storesAssembly.currencyStore
        )
    }

    public func sendV3Controller(wallet: Wallet) -> SendV3Controller {
        SendV3Controller(
            wallet: wallet,
            balanceStore: storesAssembly.convertedBalanceStore,
            dnsService: servicesAssembly.dnsService(),
            tonRatesStore: storesAssembly.tonRatesStore,
            currencyStore: storesAssembly.currencyStore,
            recipientResolver: loadersAssembly.recipientResolver(),
            amountFormatter: formattersAssembly.amountFormatter,
            multichainAssetBalanceProvider: multichainAssembly.multichainAssetBalanceProvider
        )
    }

    public func jettonTransferTransactionConfirmationController(
        wallet: Wallet,
        recipient: TonRecipient,
        jettonItem: JettonItem,
        amount: BigUInt,
        comment: String?,
        recipientDisplayAddress: String? = nil
    ) -> TransactionConfirmationController {
        JettonTransferTransactionConfirmationController(
            wallet: wallet,
            recipient: recipient,
            jettonItem: jettonItem,
            amount: amount,
            comment: comment,
            recipientDisplayAddress: recipientDisplayAddress,
            sendService: servicesAssembly.sendService(),
            blockchainService: servicesAssembly.blockchainService(),
            ratesStore: storesAssembly.tonRatesStore,
            currencyStore: storesAssembly.currencyStore,
            transferService: transferAssembly.transferService(),
            balanceService: servicesAssembly.balanceService(),
            settingsRepository: repositoriesAssembly.settingsRepository(),
            batteryCalculation: batteryAssembly.batteryCalculation
        )
    }

    public func tonTransferTransactionConfirmationController(
        wallet: Wallet,
        recipient: TonRecipient,
        amount: BigUInt,
        comment: String?,
        isMaxAmount: Bool,
        recipientDisplayAddress: String? = nil
    ) -> TransactionConfirmationController {
        TonTransferTransactionConfirmationController(
            wallet: wallet,
            recipient: recipient,
            amount: amount,
            comment: comment,
            isMaxAmount: isMaxAmount,
            recipientDisplayAddress: recipientDisplayAddress,
            sendService: servicesAssembly.sendService(),
            blockchainService: servicesAssembly.blockchainService(),
            ratesStore: storesAssembly.tonRatesStore,
            currencyStore: storesAssembly.currencyStore,
            transferService: transferAssembly.transferService()
        )
    }

    public func nftTransferTransactionConfirmationController(
        wallet: Wallet,
        recipient: TonRecipient,
        nft: NFT,
        comment: String?,
        recipientDisplayAddress: String? = nil
    ) -> TransactionConfirmationController {
        NFTTransferTransactionConfirmationController(
            wallet: wallet,
            recipient: recipient,
            nft: nft,
            comment: comment,
            recipientDisplayAddress: recipientDisplayAddress,
            sendService: servicesAssembly.sendService(),
            blockchainService: servicesAssembly.blockchainService(),
            ratesStore: storesAssembly.tonRatesStore,
            currencyStore: storesAssembly.currencyStore,
            transferService: transferAssembly.transferService(),
            settingsRepository: repositoriesAssembly.settingsRepository(),
            batteryCalculation: batteryAssembly.batteryCalculation
        )
    }

    public func tronTransferTransactionConfirmationController(
        wallet: Wallet,
        token: TronToken,
        recipient: TronRecipient,
        amount: BigUInt,
        recipientDisplayAddress: String? = nil
    ) -> TronUSDTTransactionConfirmationController {
        let walletBalance = try? servicesAssembly.balanceService().getBalance(wallet: wallet)
        let balance = switch token {
        case .usdt:
            walletBalance?.tronBalance?.amount ?? 0
        case .trx:
            walletBalance?.tronBalance?.trxAmount ?? 0
        }
        return TronUSDTTransactionConfirmationController(
            wallet: wallet,
            token: token,
            recipient: recipient,
            amount: amount,
            balance: balance,
            recipientDisplayAddress: recipientDisplayAddress,
            tronUsdtApi: tronUSDTAssembly.tronUsdtApi,
            sendService: servicesAssembly.sendService(),
            balanceService: servicesAssembly.balanceService(),
            configuration: configurationAssembly.configuration
        )
    }

    public func multichainTransferTransactionConfirmationController(
        wallet: Wallet,
        recipient: MultichainRecipient,
        asset: MultichainAsset,
        amount: BigUInt,
        comment: String?,
        isMaxAmount: Bool,
        passcodeProvider: @escaping () async -> String?
    ) -> MultichainTransactionConfirmationController {
        MultichainTransactionConfirmationController(
            wallet: wallet,
            recipient: recipient,
            asset: asset,
            amount: amount,
            comment: comment,
            isMaxAmount: isMaxAmount,
            chainKitService: multichainAssembly.chainKitService,
            passcodeProvider: passcodeProvider,
            engineResolver: MultichainFeeEngineResolver(),
            tonJettonEngineFactory: MultichainTonJettonEngineFactory(
                api: apiAssembly.api,
                sendService: servicesAssembly.sendService(),
                blockchainService: servicesAssembly.blockchainService(),
                ratesStore: storesAssembly.tonRatesStore,
                currencyStore: storesAssembly.currencyStore,
                transferService: transferAssembly.transferService(),
                balanceService: servicesAssembly.balanceService(),
                settingsRepository: repositoriesAssembly.settingsRepository(),
                batteryCalculation: batteryAssembly.batteryCalculation
            ),
            tronUsdtApi: tronUSDTAssembly.tronUsdtApi,
            sendService: servicesAssembly.sendService(),
            balanceService: servicesAssembly.balanceService(),
            configuration: configurationAssembly.configuration,
            batteryService: batteryAssembly.batteryService(),
            batteryCalculation: batteryAssembly.batteryCalculation,
            multichainAssetBalanceProvider: multichainAssembly.multichainAssetBalanceProvider
        )
    }

    public func stakingWithdrawTransactionConfirmationController(
        wallet: Wallet,
        stakingPool: StackingPoolInfo,
        amount: BigUInt,
        isCollect: Bool
    ) -> TransactionConfirmationController {
        return StakingWithdrawTransactionConfirmationController(
            wallet: wallet,
            stakingPool: stakingPool,
            amount: amount,
            isCollect: isCollect,
            sendService: servicesAssembly.sendService(),
            blockchainService: servicesAssembly.blockchainService(),
            balanceStore: storesAssembly.balanceStore,
            ratesStore: storesAssembly.tonRatesStore,
            currencyStore: storesAssembly.currencyStore
        )
    }

    public func stakingDepositTransactionConfirmationController(
        wallet: Wallet,
        stakingPool: StackingPoolInfo,
        amount: BigUInt,
        isCollect: Bool
    ) -> TransactionConfirmationController {
        return StakingDepositTransactionConfirmationController(
            wallet: wallet,
            stakingPool: stakingPool,
            amount: amount,
            isCollect: isCollect,
            sendService: servicesAssembly.sendService(),
            blockchainService: servicesAssembly.blockchainService(),
            tonBalanceService: servicesAssembly.tonBalanceService(),
            ratesStore: storesAssembly.tonRatesStore,
            currencyStore: storesAssembly.currencyStore
        )
    }

    public func signerSignController(url: URL, wallet: Wallet) -> SignerSignController {
        SignerSignController(url: url, wallet: wallet)
    }

    public func keystoneSignController(transaction: UR, wallet: Wallet) -> KeystoneSignController {
        KeystoneSignController(transaction: transaction, wallet: wallet)
    }

    public func browserExploreController() -> BrowserExploreController {
        BrowserExploreController(popularAppsService: servicesAssembly.popularAppsService())
    }

    public func linkDNSController(wallet: Wallet, nft: NFT) -> LinkDNSController {
        LinkDNSController(
            wallet: wallet,
            nft: nft,
            sendService: servicesAssembly.sendService(),
            balanceStore: storesAssembly.balanceStore,
            balanceService: servicesAssembly.balanceService()
        )
    }

    public func nativeSwapTransactionConfirmationController(
        wallet: Wallet,
        confirmation: SwapConfirmation,
        fromToken: KeeperCore.Token,
        toToken: KeeperCore.Token,
        fromAmount: BigUInt,
        transferService: TransferService,
        tonConnectService: TonConnectService,
        balanceService: BalanceService,
        settingsRepository: SettingsRepository
    ) -> TransactionConfirmationController {
        NativeSwapTransactionConfirmationController(
            wallet: wallet,
            confirmation: confirmation,
            fromToken: fromToken,
            toToken: toToken,
            fromAmount: fromAmount,
            transferService: transferService,
            tonConnectService: tonConnectService,
            balanceService: balanceService,
            settingsRepository: settingsRepository
        )
    }

    public func decryptCommentController() -> DecryptCommentController {
        DecryptCommentController(
            encryptedCommentService: servicesAssembly.encryptedCommentService(),
            decryptedCommentStore: storesAssembly.decryptedCommentStore
        )
    }
}

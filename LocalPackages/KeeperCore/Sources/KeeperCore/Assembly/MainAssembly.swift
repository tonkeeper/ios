import BigInt
import Foundation
import PerpsModels
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
    public let earnAssembly: EarnAssembly
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
        walletConnectAssembly: WalletConnectAssembly,
        earnAssembly: EarnAssembly
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
        self.earnAssembly = earnAssembly
    }

    public func scannerAssembly() -> ScannerAssembly {
        ScannerAssembly(deeplinkParser: deeplinkParser)
    }

    public var mnemonicAccess: MnemonicAccess {
        secureAssembly.mnemonicAccess
    }

    private var batteryPaymentPreparation: BatteryPaymentPreparation {
        let controller = multichainAssembly.legacyBatteryMigrationController
        let access = secureAssembly.mnemonicAccess
        let charges = BatteryChargesReader(batteryService: batteryAssembly.batteryService(), batteryCalculation: batteryAssembly.batteryCalculation)
        return BatteryPaymentPreparation(
            needsMigration: { wallet in try await controller.needsMigration(wallet: JSONEncoder().encode(wallet)) },
            migrate: { wallet, passcode in
                let authorization: LegacyBatteryMigrationController.PaymentAuthorization?
                do {
                    let mnemonic = try await access.getMnemonic(wallet: wallet, passcode: passcode)
                    authorization = try await controller.preparePayment(wallet: JSONEncoder().encode(wallet), mnemonic: mnemonic)
                }
                if let authorization { try await controller.ensureMigrated(authorization) }
            },
            currentCharges: { wallet in await charges.currentCharges(wallet: wallet) }
        )
    }

    private var offersBatteryMigration: (Wallet) async -> Bool {
        { [controller = multichainAssembly.legacyBatteryMigrationController] wallet in
            guard let data = try? JSONEncoder().encode(wallet) else { return false }
            return await controller.offersMigration(wallet: data)
        }
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
        chainKitClient: multichainAssembly.chainKitClient,
        multichainService: { [servicesAssembly] in
            servicesAssembly.multichainService()
        },
        historyEvents: { [loyaltyStore, storesAssembly] wallet in
            PerpsHistoryEvents(wallet: wallet, loyaltyStore: loyaltyStore, walletsStore: storesAssembly.walletsStore)
        },
        swapFeeMethods: { [weak self] in
            self?.perpsSwapFeeMethodResolver
        },
        perpsSignals: { [multichainAssembly] walletId in
            multichainAssembly.realtimeManager.perpsSignals(walletId: walletId)
        }
    )

    public private(set) lazy var loyaltyStore = LoyaltyStore(
        api: LoyaltyAPI(
            configuration: configurationAssembly.configuration,
            urlSession: .shared,
            authorizationService: batteryAssembly.batteryWebAuthorizationService(),
            userAgent: appInfoProvider.userAgent
        ),
        profilesVault: coreAssembly.fileSystemVault(),
        bannerHiddenVault: coreAssembly.fileSystemVault(),
        isEnabled: { [configuration = configurationAssembly.configuration] in
            configuration.featureEnabled(.loyaltyEnabled)
        }
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
            swapAPI: servicesAssembly.multichainSwapAPI(),
            swapPipeline: multichainAssembly.chainKitSwapPipeline,
            operationSteps: multichainAssembly.swapOperationSteps,
            pendingTransactionsService: servicesAssembly.pendingTransactionsService(),
            feeMethodResolver: multichainSwapFeeMethodResolver,
            gate: multichainAssembly.swapGate,
            batteryPaymentPreparation: batteryPaymentPreparation
        )

    private lazy var multichainSwapFeeMethodResolver = makeSwapFeeMethodResolver(offersMigration: offersBatteryMigration)
    private lazy var perpsSwapFeeMethodResolver = makeSwapFeeMethodResolver(offersMigration: { _ in false })

    private func makeSwapFeeMethodResolver(offersMigration: @escaping (Wallet) async -> Bool) -> MultichainSwapFeeMethodResolver {
        MultichainSwapFeeMethodResolver(
            engines: [
                MultichainSwapTonBatteryFeeEngine(
                    transferService: transferAssembly.transferService(),
                    balanceService: servicesAssembly.balanceService(),
                    batteryService: batteryAssembly.batteryService(),
                    batteryCalculation: batteryAssembly.batteryCalculation,
                    configuration: configurationAssembly.configuration,
                    chainKitService: multichainAssembly.chainKitService,
                    mnemonicAccess: secureAssembly.mnemonicAccess,
                    offersBatteryMigration: offersMigration
                ),
                MultichainSwapTronRelayedFeeEngine(
                    tronUsdtApi: tronUSDTAssembly.tronUsdtApi,
                    sendService: servicesAssembly.sendService(),
                    balanceService: servicesAssembly.balanceService(),
                    batteryService: batteryAssembly.batteryService(),
                    batteryCalculation: batteryAssembly.batteryCalculation,
                    configuration: configurationAssembly.configuration,
                    chainKitService: multichainAssembly.chainKitService,
                    mnemonicAccess: secureAssembly.mnemonicAccess,
                    offersBatteryMigration: offersMigration
                ),
            ] + evmSwapRelayedFeeEngines(offersMigration: offersMigration)
        )
    }

    private func evmSwapRelayedFeeEngines(offersMigration: @escaping (Wallet) async -> Bool) -> [any MultichainSwapRelayedFeeEngine] {
        let configuration = configurationAssembly.configuration
        let chargesReader = BatteryChargesReader(
            batteryService: batteryAssembly.batteryService(),
            batteryCalculation: batteryAssembly.batteryCalculation,
            offersMigration: offersMigration
        )
        let balanceProvider = multichainAssembly.multichainAssetBalanceProvider
        let relayer = BatteryEVMGaslessRelayer(service: batteryAssembly.batteryGaslessService())
        let signer = multichainAssembly.relayedOperationSigner
        let relayedChains = evmGaslessRelayedChains
        return MultichainChain.allCases
            .filter { $0.isEVM || $0 == .sol }
            .sorted { $0.rawValue < $1.rawValue }
            .map { chain in
                MultichainSwapEVMRelayedFeeEngine(
                    chain: chain,
                    relayer: relayer,
                    signer: signer,
                    relayedChains: { await relayedChains.chains() },
                    isRelayerEnabled: { wallet in
                        guard await configuration.isBatteryEnable(network: wallet.network) else {
                            return false
                        }
                        return await configuration.isBatterySendEnable(network: wallet.network)
                    },
                    batteryCharges: { wallet in
                        await chargesReader.availableCharges(wallet: wallet)
                    },
                    walletTokens: { assetIds, wallet in
                        await balanceProvider.loadAssets(named: assetIds, wallet: wallet)
                    },
                    currentBatteryCharges: { wallet in await chargesReader.currentCharges(wallet: wallet) },
                    offersBatteryMigration: offersMigration
                )
            }
    }

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
            multichainAssetBalanceProvider: multichainAssembly.multichainAssetBalanceProvider,
            accountService: servicesAssembly.accountService(),
            accountPublicKey: { [apiProvider = apiAssembly.apiProvider] address, network in
                try await apiProvider.api(network).getAccountPublicKey(address: address)
            }
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
            configuration: configurationAssembly.configuration,
            gate: multichainAssembly.sendGate
        )
    }

    public func multichainTransferTransactionConfirmationController(
        wallet: Wallet,
        recipient: MultichainRecipient,
        asset: MultichainAsset,
        amount: BigUInt,
        comment: String?,
        commentEncryptionKey: String? = nil,
        isMaxAmount: Bool,
        signer: MultichainTransferSigner
    ) -> MultichainTransactionConfirmationController {
        MultichainTransactionConfirmationController(
            wallet: wallet,
            recipient: recipient,
            asset: asset,
            amount: amount,
            comment: comment,
            commentEncryptionKey: commentEncryptionKey,
            isMaxAmount: isMaxAmount,
            chainKitService: multichainAssembly.chainKitService,
            signer: signer,
            engineResolver: MultichainFeeEngineResolver(
                relayedEVMChains: batteryRelayedEVMChains,
                relays: { [configuration = configurationAssembly.configuration] in configuration.relaysGasless(on: $0) }
            ),
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
            multichainAssetBalanceProvider: multichainAssembly.multichainAssetBalanceProvider,
            evmGaslessFeeEngine: evmGaslessFeeEngine(),
            gate: multichainAssembly.sendGate,
            offersBatteryMigration: offersBatteryMigration,
            batteryPaymentPreparation: batteryPaymentPreparation
        )
    }

    private lazy var evmGaslessRelayedChains = EVMGaslessRelayedChains(
        loadConfig: { [service = batteryAssembly.batteryGaslessService()] in
            try await service.gaslessConfig()
        },
        includes: { [configuration = configurationAssembly.configuration] chain in
            configuration.relaysGasless(on: chain)
        }
    )

    /// The EVM chains and Solana the battery's relayer pays fees on, `nil` until its config has been read.
    public var batteryRelayedEVMChains: @Sendable () async -> Set<MultichainChain>? {
        { [relayedChains = evmGaslessRelayedChains] in await relayedChains.chains() }
    }

    /// The swaps a wallet's battery would pay for, `nil` unless the battery was read and holds no charges.
    public func emptyBatterySwapCoverage(swapWallet: MultichainSwapWallet) async -> MultichainSwapBatteryCoverage? {
        let wallet = swapWallet.wallet
        let chargesReader = BatteryChargesReader(
            batteryService: batteryAssembly.batteryService(),
            batteryCalculation: batteryAssembly.batteryCalculation,
            offersMigration: offersBatteryMigration
        )
        guard await chargesReader.availableCharges(wallet: wallet) == .available(0) else {
            return nil
        }
        let configuration = configurationAssembly.configuration
        let isBatteryEnabled = await configuration.isBatteryEnable(network: wallet.network)
        let isBatterySendEnabled = await configuration.isBatterySendEnable(network: wallet.network)
        return await MultichainSwapBatteryCoverage(
            swapWallet: swapWallet,
            isBatteryEnabled: isBatteryEnabled && isBatterySendEnabled,
            isTRXOnlyRegion: configuration.isTRXOnlyRegion(network: wallet.network),
            relayedEVMChains: evmGaslessRelayedChains.chains() ?? []
        )
    }

    private func evmGaslessFeeEngine() -> EVMGaslessFeeEngine {
        let configuration = configurationAssembly.configuration
        let chargesReader = BatteryChargesReader(
            batteryService: batteryAssembly.batteryService(),
            batteryCalculation: batteryAssembly.batteryCalculation,
            offersMigration: offersBatteryMigration
        )
        let balanceProvider = multichainAssembly.multichainAssetBalanceProvider
        return EVMGaslessFeeEngine(
            relayer: BatteryEVMGaslessRelayer(service: batteryAssembly.batteryGaslessService()),
            signer: multichainAssembly.relayedOperationSigner,
            isEnabled: { wallet in
                guard await configuration.isBatteryEnable(network: wallet.network) else {
                    return false
                }
                return await configuration.isBatterySendEnable(network: wallet.network)
            },
            batteryCharges: { wallet in
                await chargesReader.availableCharges(wallet: wallet)
            },
            walletTokens: { assetIds, wallet in
                await balanceProvider.loadAssets(named: assetIds, wallet: wallet)
            },
            gate: multichainAssembly.sendGate,
            currentBatteryCharges: { wallet in await chargesReader.currentCharges(wallet: wallet) },
            offersBatteryMigration: offersBatteryMigration
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
        settingsRepository: SettingsRepository,
        isEmulationEnabled: Bool
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
            settingsRepository: settingsRepository,
            isEmulationEnabled: isEmulationEnabled
        )
    }

    public func decryptCommentController() -> DecryptCommentController {
        DecryptCommentController(
            encryptedCommentService: servicesAssembly.encryptedCommentService(),
            decryptedCommentStore: storesAssembly.decryptedCommentStore
        )
    }
}

import Foundation
import TKFeatureFlags
import TKLogging
import TonSwift

public final class LoadersAssembly {
    private let servicesAssembly: ServicesAssembly
    private let storesAssembly: StoresAssembly
    private let tonkeeperAPIAssembly: TonkeeperAPIAssembly
    private let apiAssembly: APIAssembly
    private let knownAccountsAssembly: KnownAccountsAssembly
    private let tronAssembly: TronUSDTAssembly
    private let configurationAssembly: ConfigurationAssembly
    private let tkAppSettings: TKAppSettings

    init(
        servicesAssembly: ServicesAssembly,
        storesAssembly: StoresAssembly,
        tonkeeperAPIAssembly: TonkeeperAPIAssembly,
        apiAssembly: APIAssembly,
        knownAccountsAssembly: KnownAccountsAssembly,
        tronAssembly: TronUSDTAssembly,
        configurationAssembly: ConfigurationAssembly,
        tkAppSettings: TKAppSettings
    ) {
        self.servicesAssembly = servicesAssembly
        self.storesAssembly = storesAssembly
        self.tonkeeperAPIAssembly = tonkeeperAPIAssembly
        self.apiAssembly = apiAssembly
        self.knownAccountsAssembly = knownAccountsAssembly
        self.tronAssembly = tronAssembly
        self.configurationAssembly = configurationAssembly
        self.tkAppSettings = tkAppSettings
    }

    private weak var _walletInfoLoader: WalletInfoLoader?
    var walletInfoLoader: WalletInfoLoader {
        if let _walletInfoLoader {
            return _walletInfoLoader
        }
        let loader = WalletInfoLoader(
            walletsStore: storesAssembly.walletsStore,
            walletService: servicesAssembly.walletService(),
            internalNotificationsStore: storesAssembly.internalNotificationsStore
        )
        _walletInfoLoader = loader
        return loader
    }

    private weak var _internalNotificationsLoader: InternalNotificationsLoader?
    var internalNotificationsLoader: InternalNotificationsLoader {
        if let _internalNotificationsLoader {
            return _internalNotificationsLoader
        }
        let loader = InternalNotificationsLoader(
            tonkeeperAPI: tonkeeperAPIAssembly.api,
            notificationsStore: storesAssembly.internalNotificationsStore,
            walletsStore: storesAssembly.walletsStore
        )
        _internalNotificationsLoader = loader
        return loader
    }

    private var _homeBannersLoader: HomeBannersLoader?
    public var homeBannersLoader: HomeBannersLoader {
        if let _homeBannersLoader {
            return _homeBannersLoader
        }
        let loader = HomeBannersLoader(
            tonkeeperAPI: tonkeeperAPIAssembly.api,
            homeBannersStore: storesAssembly.homeBannersStore,
            walletsStore: storesAssembly.walletsStore
        )
        _homeBannersLoader = loader
        return loader
    }

    private var _raffleLoader: RaffleLoader?
    public var raffleLoader: RaffleLoader {
        if let _raffleLoader {
            return _raffleLoader
        }
        let loader = RaffleLoader(
            multichainService: servicesAssembly.multichainService(),
            raffleStore: storesAssembly.raffleStore,
            appSettings: tkAppSettings
        )
        _raffleLoader = loader
        return loader
    }

    public func historyAllEventsPaginationLoader(wallet: Wallet) -> HistoryPaginationLoader {
        historyPaginationLoader(
            wallet: wallet,
            loader: HistoryListAllEventsLoader(
                historyService: servicesAssembly.historyService(),
                tronUsdtApi: tronAssembly.tronUsdtApi
            )
        )
    }

    public func historyTonEventsPaginationLoader(wallet: Wallet) -> HistoryPaginationLoader {
        historyPaginationLoader(
            wallet: wallet,
            loader: HistoryListTonEventsLoader(
                historyService: servicesAssembly.historyService()
            )
        )
    }

    public func historyJettonEventsPaginationLoader(
        wallet: Wallet,
        jettonMasterAddress: Address
    ) -> HistoryPaginationLoader {
        historyPaginationLoader(
            wallet: wallet,
            loader: HistoryListJettonEventsLoader(
                jettonMasterAddress: jettonMasterAddress,
                historyService: servicesAssembly.historyService()
            )
        )
    }

    public func historyTronUSDTEventsPaginationLoader(wallet: Wallet) -> HistoryPaginationLoader {
        historyPaginationLoader(
            wallet: wallet,
            loader: HistoryListTronUSDTEventsLoader(
                historyService: servicesAssembly.historyService(),
                tronUsdtApi: tronAssembly.tronUsdtApi
            )
        )
    }

    public func historyTronTRXEventsPaginationLoader(wallet: Wallet) -> HistoryPaginationLoader {
        historyPaginationLoader(
            wallet: wallet,
            loader: HistoryListTronTRXEventsLoader(tronUsdtApi: tronAssembly.tronUsdtApi)
        )
    }

    func historyPaginationLoader(
        wallet: Wallet,
        loader: HistoryListLoader
    ) -> HistoryPaginationLoader {
        HistoryPaginationLoader(
            wallet: wallet,
            loader: loader,
            nftService: servicesAssembly.nftService()
        )
    }

    private weak var _balanceLoader: BalanceLoader?
    public var balanceLoader: BalanceLoader {
        if let _balanceLoader {
            return _balanceLoader
        }
        let loader = BalanceLoaderImplementation(
            walletStore: storesAssembly.walletsStore,
            currencyStore: storesAssembly.currencyStore,
            ratesStore: storesAssembly.tonRatesStore,
            ratesService: servicesAssembly.ratesService(),
            walletStateLoaderProvider: { self.walletBalanceLoaders(wallet: $0) },
            makeTotalBalanceLoader: { loadWalletBalance in
                TotalBalanceLoaderImplementation(
                    balanceStore: storesAssembly.balanceStore,
                    multichainPortfolioStore: storesAssembly.multichainPortfolioStore,
                    loadPortfolioTotal: { [servicesAssembly, storesAssembly] wallet, state, currency in
                        let requestToken = storesAssembly.multichainPortfolioStore.makeRequestToken()
                        let hidesDustBalances = storesAssembly.appSettingsStore.getState().hidesDustBalances
                        do {
                            let page = try await servicesAssembly.multichainService().getAllWalletAssets(
                                state: state,
                                currencies: {
                                    var codes = [currency.code.lowercased()]
                                    if currency != .defaultCurrency {
                                        codes.append(Currency.defaultCurrency.code.lowercased())
                                    }
                                    return codes
                                }(),
                                capabilities: nil,
                                chain: nil,
                                search: nil,
                                availableOnly: nil,
                                showHidden: false,
                                hideDust: hidesDustBalances ? true : nil
                            )
                            guard !Task.isCancelled else { return }
                            storesAssembly.multichainPortfolioStore.setPortfolio(
                                MultichainPortfolio(
                                    fiatPrice: page.fiatPrice,
                                    assets: page.assets.filter { !$0.isHidden },
                                    accountsIdentifier: state.accountsIdentifier,
                                    currencyCode: currency.code.lowercased(),
                                    hidesDustBalances: hidesDustBalances
                                ),
                                wallet: wallet,
                                requestToken: requestToken
                            )
                        } catch {
                            Log.w("Multichain: failed to load portfolio total for wallet list: \(error)")
                        }
                    },
                    loadWalletBalance: loadWalletBalance,
                    hidesDustBalances: { [storesAssembly] in
                        storesAssembly.appSettingsStore.getState().hidesDustBalances
                    }
                )
            }
        )
        _balanceLoader = loader
        return loader
    }

    private let walletBalanceLoadersLock = NSLock()
    private var _walletBalanceLoaders = [Wallet: () -> WalletBalanceLoader?]()
    public func walletBalanceLoaders(wallet: Wallet) -> WalletBalanceLoader {
        walletBalanceLoadersLock.withLock {
            if let store = _walletBalanceLoaders[wallet]?() {
                return store
            }
            let store = WalletBalanceLoaderImplementation(
                wallet: wallet,
                balanceStore: storesAssembly.balanceStore,
                stakingPoolsStore: storesAssembly.stackingPoolsStore,
                walletNFTSStore: storesAssembly.walletNFTsStore(wallet: wallet, nftService: servicesAssembly.accountNftService()),
                balanceService: servicesAssembly.balanceService(),
                stackingService: servicesAssembly.stackingService(),
                accountNFTService: servicesAssembly.accountNftService()
            )
            _walletBalanceLoaders[wallet] = { [weak store] in store }
            return store
        }
    }

    public func recipientResolver() -> RecipientResolver {
        RecipientResolverImplementation(
            dnsService: servicesAssembly.dnsService(),
            accountService: servicesAssembly.accountService()
        )
    }

    public func insufficientFundsValidator() -> InsufficientFundsValidator {
        InsufficientFundsValidatorImplementation(
            balanceStore: storesAssembly.balanceStore,
            apiProvider: apiAssembly.apiProvider
        )
    }

    private var _ethenaStakingLoaders = [Wallet: Weak<EthenaStakingLoader>]()
    public func ethenaStakingLoader(wallet: Wallet) -> EthenaStakingLoader {
        if let weakWrapper = _ethenaStakingLoaders[wallet],
           let loader = weakWrapper.value
        {
            return loader
        }

        let loader = EthenaStakingLoader(wallet: wallet, api: tonkeeperAPIAssembly.api)
        _ethenaStakingLoaders[wallet] = Weak(value: loader)
        return loader
    }
}

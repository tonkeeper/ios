import Foundation
import TonSwift

public final class LoadersAssembly {
    private let servicesAssembly: ServicesAssembly
    private let storesAssembly: StoresAssembly
    private let tonkeeperAPIAssembly: TonkeeperAPIAssembly
    private let apiAssembly: APIAssembly
    private let knownAccountsAssembly: KnownAccountsAssembly
    private let tronAssembly: TronUSDTAssembly
    private let configurationAssembly: ConfigurationAssembly

    init(
        servicesAssembly: ServicesAssembly,
        storesAssembly: StoresAssembly,
        tonkeeperAPIAssembly: TonkeeperAPIAssembly,
        apiAssembly: APIAssembly,
        knownAccountsAssembly: KnownAccountsAssembly,
        tronAssembly: TronUSDTAssembly,
        configurationAssembly: ConfigurationAssembly
    ) {
        self.servicesAssembly = servicesAssembly
        self.storesAssembly = storesAssembly
        self.tonkeeperAPIAssembly = tonkeeperAPIAssembly
        self.apiAssembly = apiAssembly
        self.knownAccountsAssembly = knownAccountsAssembly
        self.tronAssembly = tronAssembly
        self.configurationAssembly = configurationAssembly
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

    private weak var _storiesLoader: StoriesLoader?
    var storiesLoader: StoriesLoader {
        if let _storiesLoader {
            return _storiesLoader
        }
        let loader = StoriesLoader(
            tonkeeperAPI: tonkeeperAPIAssembly.api,
            configuration: configurationAssembly.configuration,
            storiesStore: storesAssembly.storiesStore
        )
        _storiesLoader = loader
        return loader
    }

    private weak var _internalNotificationsLoader: InternalNotificationsLoader?
    var internalNotificationsLoader: InternalNotificationsLoader {
        if let _internalNotificationsLoader {
            return _internalNotificationsLoader
        }
        let loader = InternalNotificationsLoader(
            tonkeeperAPI: tonkeeperAPIAssembly.api,
            notificationsStore: storesAssembly.internalNotificationsStore
        )
        _internalNotificationsLoader = loader
        return loader
    }

    public func historyAllEventsPaginationLoader(wallet: Wallet) -> HistoryPaginationLoader {
        historyPaginationLoader(
            wallet: wallet,
            loader: HistoryListAllEventsLoader(
                historyService: servicesAssembly.historyService(),
                tonProofTokenService: servicesAssembly.tonProofTokenService(),
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
                tonProofTokenService: servicesAssembly.tonProofTokenService(),
                tronUsdtApi: tronAssembly.tronUsdtApi
            )
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
        let loader = BalanceLoader(
            walletStore: storesAssembly.walletsStore,
            currencyStore: storesAssembly.currencyStore,
            ratesStore: storesAssembly.tonRatesStore,
            ratesService: servicesAssembly.ratesService(),
            walletStateLoaderProvider: { self.walletBalanceLoaders(wallet: $0) }
        )
        _balanceLoader = loader
        return loader
    }

    private var _walletBalanceLoaders = [Wallet: Weak<WalletBalanceLoader>]()
    public func walletBalanceLoaders(wallet: Wallet) -> WalletBalanceLoader {
        if let weakWrapper = _walletBalanceLoaders[wallet],
           let store = weakWrapper.value
        {
            return store
        }
        let store = WalletBalanceLoader(
            wallet: wallet,
            balanceStore: storesAssembly.balanceStore,
            stakingPoolsStore: storesAssembly.stackingPoolsStore,
            walletNFTSStore: storesAssembly.walletNFTsStore(wallet: wallet, nftService: servicesAssembly.accountNftService()),
            balanceService: servicesAssembly.balanceService(),
            stackingService: servicesAssembly.stackingService(),
            accountNFTService: servicesAssembly.accountNftService()
        )
        _walletBalanceLoaders[wallet] = Weak(value: store)
        return store
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

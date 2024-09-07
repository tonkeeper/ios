import Foundation
import TonSwift

public final class StoresAssembly {
  
  private let servicesAssembly: ServicesAssembly
  private let apiAssembly: APIAssembly
  private let coreAssembly: CoreAssembly
  private let repositoriesAssembly: RepositoriesAssembly
  
  init(servicesAssembly: ServicesAssembly,
       apiAssembly: APIAssembly,
       coreAssembly: CoreAssembly,
       repositoriesAssembly: RepositoriesAssembly) {
    self.servicesAssembly = servicesAssembly
    self.apiAssembly = apiAssembly
    self.coreAssembly = coreAssembly
    self.repositoriesAssembly = repositoriesAssembly
  }
  
  private weak var _keeperInfoStore: KeeperInfoStore?
  public var keeperInfoStore: KeeperInfoStore {
    if let _keeperInfoStore {
      return _keeperInfoStore
    }
    let store = KeeperInfoStore(keeperInfoRepository: repositoriesAssembly.keeperInfoRepository())
    _keeperInfoStore = store
    return store
  }
  
  private weak var _keeperInfoStoreV3: KeeperInfoStoreV3?
  public var keeperInfoStoreV3: KeeperInfoStoreV3 {
    if let _keeperInfoStoreV3 {
      return _keeperInfoStoreV3
    }
    let store = KeeperInfoStoreV3(keeperInfoRepository: repositoriesAssembly.keeperInfoRepository())
    _keeperInfoStoreV3 = store
    return store
  }
  
  private weak var _walletsStore: WalletsStoreV3?
  public var walletsStore: WalletsStoreV3 {
    if let _walletsStore {
      return _walletsStore
    }
    let store = WalletsStoreV3(keeperInfoStore: keeperInfoStoreV3)
    _walletsStore = store
    return store
  }
  
  private weak var _balanceStore: BalanceStoreV3?
  public var balanceStore: BalanceStoreV3 {
    if let _balanceStore {
      return _balanceStore
    }
    let store = BalanceStoreV3(walletsStore: walletsStore,
                               repository: repositoriesAssembly.walletBalanceRepositoryV2()
    )
    _balanceStore = store
    return store
  }
  
  private weak var _convertedBalanceStore: ConvertedBalanceStore?
    public var convertedBalanceStore: ConvertedBalanceStore {
      if let _convertedBalanceStore {
        return _convertedBalanceStore
      }
      let store = ConvertedBalanceStore(
        walletsStore: walletsStore,
        balanceStore: balanceStore,
        tonRatesStore: tonRatesStoreV3,
        currencyStore: currencyStoreV3

      )
      _convertedBalanceStore = store
      return store
    }
  
  private weak var _processedBalanceStore: ProcessedBalanceStore?
  public var processedBalanceStore: ProcessedBalanceStore {
    if let _processedBalanceStore {
      return _processedBalanceStore
    }
    let store = ProcessedBalanceStore(
      walletsStore: walletsStore,
      balanceStore: balanceStore,
      tonRatesStore: tonRatesStoreV3,
      currencyStore: currencyStoreV3,
      stakingPoolsStore: stackingPoolsStore
    )
    _processedBalanceStore = store
    return store
  }
  
  private weak var _totalBalanceStore: TotalBalanceStore?
  public var totalBalanceStore: TotalBalanceStore {
    if let _totalBalanceStore {
      return _totalBalanceStore
    }
    let store = TotalBalanceStore(processedBalanceStore: processedBalanceStore)
    _totalBalanceStore = store
    return store
  }
  
  private weak var _currencyStore: CurrencyStore?
  public var currencyStore: CurrencyStore {
    if let _currencyStore {
      return _currencyStore
    }
    let store = CurrencyStore(keeperInfoStore: keeperInfoStore)
    _currencyStore = store
    return store
  }
  
  private weak var _currencyStoreV3: CurrencyStoreV3?
  public var currencyStoreV3: CurrencyStoreV3 {
    if let _currencyStoreV3 {
      return _currencyStoreV3
    }
    let store = CurrencyStoreV3(keeperInfoStore: keeperInfoStoreV3)
    _currencyStoreV3 = store
    return store
  }
  
  private weak var _tonRatesStore: TonRatesStore?
  public var tonRatesStore: TonRatesStore {
    if let tonRatesStore = _tonRatesStore {
      return tonRatesStore
    } else {
      let tonRatesStore = TonRatesStore(
        repository: repositoriesAssembly.ratesRepository()
      )
      _tonRatesStore = tonRatesStore
      return tonRatesStore
    }
  }
  
  private weak var _tonRatesStoreV3: TonRatesStoreV3?
  public var tonRatesStoreV3: TonRatesStoreV3 {
    if let tonRatesStoreV3 = _tonRatesStoreV3 {
      return tonRatesStoreV3
    } else {
      let tonRatesStore = TonRatesStoreV3(
        repository: repositoriesAssembly.ratesRepository()
      )
      _tonRatesStoreV3 = tonRatesStore
      return tonRatesStore
    }
  }
  
  private weak var _nftsStore: NFTStore?
  public var nftsStore: NFTStore {
    if let _nftsStore {
      return _nftsStore
    }
    let nftsStore = NFTStore(
      repository: repositoriesAssembly.nftRepository()
    )
    _nftsStore = nftsStore
    return nftsStore
  }
  
  private weak var _walletNFTsStore: WalletNFTStore?
  public var walletNFTsStore: WalletNFTStore {
    if let _walletNFTsStore {
      return _walletNFTsStore
    }
    let walletNFTsStore = WalletNFTStore(
      walletsStore: walletsStore,
      nftStore: nftsStore,
      repository: repositoriesAssembly.walletNFTRepository()
    )
    _walletNFTsStore = walletNFTsStore
    return walletNFTsStore
  }
  
  private weak var _securityStore: SecurityStore?
  public var securityStore: SecurityStore {
    if let securityStore = _securityStore {
      return securityStore
    } else {
      let securityStore = SecurityStore(keeperInfoStore: keeperInfoStoreV3)
      _securityStore = securityStore
      return securityStore
    }
  }
  
  private weak var _stackingPoolsStore: StakingPoolsStore?
  public var stackingPoolsStore: StakingPoolsStore {
    if let store = _stackingPoolsStore {
      return store
    } else {
      let store = StakingPoolsStore()
      _stackingPoolsStore = store
      return store
    }
  }
 
  private weak var _internalNotificationsStore: InternalNotificationsStore?
  public var internalNotificationsStore: InternalNotificationsStore {
    if let store = _internalNotificationsStore {
      return store
    } else {
      let store = InternalNotificationsStore()
      _internalNotificationsStore = store
      return store
    }
  }
  
  private var _tokenManagementStore: TokenManagementStore?
  public var tokenManagementStore: TokenManagementStore {
    if let tokenManagementStore = _tokenManagementStore {
      return tokenManagementStore
    } else {
      let tokenManagementStore = TokenManagementStore(
        walletsStore: walletsStore,
        tokenManagementRepository: repositoriesAssembly.tokenManagementRepository()
      )
      _tokenManagementStore = tokenManagementStore
      return tokenManagementStore
    }
  }
  
  private var _walletNFTsManagementStore = [Wallet: Weak<WalletNFTsManagementStore>]()
  public func walletNFTsManagementStore(wallet: Wallet) -> WalletNFTsManagementStore {
    if let weakWrapper = _walletNFTsManagementStore[wallet],
       let store = weakWrapper.value {
      return store
    }
    let store = WalletNFTsManagementStore(
      wallet: wallet,
      accountNFTsManagementRepository: repositoriesAssembly.accountNFTsManagementRepository()
    )
    _walletNFTsManagementStore[wallet] = Weak(value: store)
    return store
  }
  
  private weak var _knownAccountsStore: KnownAccountsStore?
  var knownAccountsStore: KnownAccountsStore {
    if let knownAccountsStore = _knownAccountsStore {
      return knownAccountsStore
    } else {
      let knownAccountsStore = KnownAccountsStore(
        knownAccountsService: servicesAssembly.knownAccountsService()
      )
      _knownAccountsStore = knownAccountsStore
      return knownAccountsStore
    }
  }
  
  private weak var _fiatMethodsStore: FiatMethodsStore?
  public var fiatMethodsStore: FiatMethodsStore {
    if let fiatMethodsStore = _fiatMethodsStore {
      return fiatMethodsStore
    } else {
      let fiatMethodsStore = FiatMethodsStore()
      _fiatMethodsStore = fiatMethodsStore
      return fiatMethodsStore
    }
  }
  
  private weak var _walletNotificationStore: WalletNotificationStore?
  public var walletNotificationStore: WalletNotificationStore {
    if let walletNotificationStore = _walletNotificationStore {
      return walletNotificationStore
    } else {
      let walletNotificationStore = WalletNotificationStore(keeperInfoStore: keeperInfoStore)
      _walletNotificationStore = walletNotificationStore
      return walletNotificationStore
    }
  }
  
  private weak var _backgroundUpdateStore: BackgroundUpdateStoreV3?
  public var backgroundUpdateStore: BackgroundUpdateStoreV3 {
    if let backgroundUpdateStore = _backgroundUpdateStore {
      return backgroundUpdateStore
    } else {
      let backgroundUpdateStore = BackgroundUpdateStoreV3()
      _backgroundUpdateStore = backgroundUpdateStore
      return backgroundUpdateStore
    }
  }
  
  private weak var _backgroundUpdateUpdater: BackgroundUpdateUpdater?
  public var backgroundUpdateUpdater: BackgroundUpdateUpdater {
    if let backgroundUpdateUpdater = _backgroundUpdateUpdater {
      return backgroundUpdateUpdater
    } else {
      let backgroundUpdateUpdater = BackgroundUpdateUpdater(
        backgroundUpdateStore: backgroundUpdateStore,
        walletsStore: walletsStore,
        streamingAPI: apiAssembly.streamingTonAPIClient()
      )
      _backgroundUpdateUpdater = backgroundUpdateUpdater
      return backgroundUpdateUpdater
    }
  }
  
  private weak var _appSettingsStore: AppSettingsV3Store?
  public var appSettingsStore: AppSettingsV3Store {
    if let appSettingsStore = _appSettingsStore {
      return appSettingsStore
    } else {
      let appSettingsStore = AppSettingsV3Store(keeperInfoStore: keeperInfoStoreV3)
      _appSettingsStore = appSettingsStore
      return appSettingsStore
    }
  }
}

class Weak<T: AnyObject> {
  weak var value : T?
  init (value: T) {
    self.value = value
  }
}

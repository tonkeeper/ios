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
  
  private weak var _processedBalanceStore: ProcessedBalanceStoreV3?
  public var processedBalanceStore: ProcessedBalanceStoreV3 {
    if let _processedBalanceStore {
      return _processedBalanceStore
    }
    let store = ProcessedBalanceStoreV3(
      walletsStore: walletsStore,
      balanceStore: balanceStore,
      tonRatesStore: tonRatesStoreV3,
      currencyStore: currencyStoreV3,
      stakingPoolsStore: stackingPoolsStoreV3
    )
    _processedBalanceStore = store
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
  
  private weak var _securityStore: SecurityStore?
  public var securityStore: SecurityStore {
    if let securityStore = _securityStore {
      return securityStore
    } else {
      let securityStore = SecurityStore(keeperInfoStore: keeperInfoStore)
      _securityStore = securityStore
      return securityStore
    }
  }
  
  private weak var _setupStore: SetupStore?
  public var setupStore: SetupStore {
    if let setupStore = _setupStore {
      return setupStore
    } else {
      let setupStore = SetupStore(keeperInfoStore: keeperInfoStore)
      _setupStore = setupStore
      return setupStore
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
  
  private weak var _stackingPoolsStoreV3: StakingPoolsStoreV3?
  public var stackingPoolsStoreV3: StakingPoolsStoreV3 {
    if let store = _stackingPoolsStoreV3 {
      return store
    } else {
      let store = StakingPoolsStoreV3()
      _stackingPoolsStoreV3 = store
      return store
    }
  }
  
  private weak var _notificationsStore: NotificationsStore?
  public var notificationsStore: NotificationsStore {
    if let store = _notificationsStore {
      return store
    } else {
      let store = NotificationsStore()
      _notificationsStore = store
      return store
    }
  }
  
  private var _tokenManagementStores = [Wallet: Weak<TokenManagementStore>]()
  public func tokenManagementStore(wallet: Wallet) -> TokenManagementStore {
    if let weakWrapper = _tokenManagementStores[wallet],
       let store = weakWrapper.value {
      return store
    }
    let store = TokenManagementStore(
      wallet: wallet,
      tokenManagementRepository: repositoriesAssembly.tokenManagementRepository()
    )
    _tokenManagementStores[wallet] = Weak(value: store)
    return store
  }
  
  private weak var _nftsStore: NftsStore?
  var nftsStore: NftsStore {
    if let _nftsStore {
      return _nftsStore
    }
    let nftsStore = NftsStore(service: servicesAssembly.accountNftService())
    _nftsStore = nftsStore
    return nftsStore
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
}

class Weak<T: AnyObject> {
  weak var value : T?
  init (value: T) {
    self.value = value
  }
}

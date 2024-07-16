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
  
  private weak var _currencyStoreV2: CurrencyStoreV2?
  public var currencyStoreV2: CurrencyStoreV2 {
    if let _currencyStoreV2 {
      return _currencyStoreV2
    }
    let store = CurrencyStoreV2(keeperInfoStore: keeperInfoStore)
    _currencyStoreV2 = store
    return store
  }
  
  private weak var _tonRatesStoreV2: TonRatesStoreV2?
  public var tonRatesStoreV2: TonRatesStoreV2 {
    if let tonRatesStore = _tonRatesStoreV2 {
      return tonRatesStore
    } else {
      let tonRatesStore = TonRatesStoreV2(
        repository: repositoriesAssembly.ratesRepository()
      )
      _tonRatesStoreV2 = tonRatesStore
      return tonRatesStore
    }
  }
  
  private weak var _securityStoreV2: SecurityStoreV2?
  public var securityStoreV2: SecurityStoreV2 {
    if let securityStore = _securityStoreV2 {
      return securityStore
    } else {
      let securityStore = SecurityStoreV2(keeperInfoStore: keeperInfoStore)
      _securityStoreV2 = securityStore
      return securityStore
    }
  }
  
  private weak var _setupStoreV2: SetupStoreV2?
  public var setupStoreV2: SetupStoreV2 {
    if let setupStore = _setupStoreV2 {
      return setupStore
    } else {
      let setupStore = SetupStoreV2(keeperInfoStore: keeperInfoStore)
      _setupStoreV2 = setupStore
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
  
  private weak var _backgroundUpdateStoreV2: BackgroundUpdateStoreV2?
  public var backgroundUpdateStoreV2: BackgroundUpdateStoreV2 {
    if let backgroundUpdateStore = _backgroundUpdateStoreV2 {
      return backgroundUpdateStore
    } else {
      let backgroundUpdateStore = BackgroundUpdateStoreV2()
      _backgroundUpdateStoreV2 = backgroundUpdateStore
      return backgroundUpdateStore
    }
  }
  
  private weak var _backgroundUpdateUpdater: BackgroundUpdateUpdater?
  public var backgroundUpdateUpdater: BackgroundUpdateUpdater {
    if let backgroundUpdateUpdater = _backgroundUpdateUpdater {
      return backgroundUpdateUpdater
    } else {
      let backgroundUpdateUpdater = BackgroundUpdateUpdater(
        backgroundUpdateStore: backgroundUpdateStoreV2,
        streamingAPI: apiAssembly.streamingTonAPIClient()
      )
      _backgroundUpdateUpdater = backgroundUpdateUpdater
      return backgroundUpdateUpdater
    }
  }
  
  private weak var _walletBalanceStore: WalletBalanceStore?
  var walletBalanceStore: WalletBalanceStore {
    if let _walletBalanceStore {
      return _walletBalanceStore
    }
    let walletBalanceStore = WalletBalanceStore(
      repository: repositoriesAssembly.walletBalanceRepository()
    )
    _walletBalanceStore = walletBalanceStore
    return walletBalanceStore
  }
  
  private weak var _tonRatesStore: TonRatesStore?
  var tonRatesStore: TonRatesStore {
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
  
  private weak var _nftsStore: NftsStore?
  var nftsStore: NftsStore {
    if let _nftsStore {
      return _nftsStore
    }
    let nftsStore = NftsStore(service: servicesAssembly.accountNftService())
    _nftsStore = nftsStore
    return nftsStore
  }
  
  private weak var _balanceStore: BalanceStore?
  var balanceStore: BalanceStore {
    if let balanceStore = _balanceStore {
      return balanceStore
    } else {
      let balanceStore = BalanceStore(balanceService: servicesAssembly.balanceService())
      _balanceStore = balanceStore
      return balanceStore
    }
  }
  
  private weak var _ratesStore: RatesStore?
  var ratesStore: RatesStore {
    if let ratesStore = _ratesStore {
      return ratesStore
    } else {
      let ratesStore = RatesStore(ratesService: servicesAssembly.ratesService())
      _ratesStore = ratesStore
      return ratesStore
    }
  }
  
  private weak var _currencyStore: CurrencyStore?
  public var currencyStore: CurrencyStore {
    if let currencyStore = _currencyStore {
      return currencyStore
    } else {
      let currencyStore = CurrencyStore(currencyService: servicesAssembly.currencyService())
      _currencyStore = currencyStore
      return currencyStore
    }
  }
  
  private weak var _backupStore: BackupStore?
  var backupStore: BackupStore {
    if let backupStore = _backupStore {
      return backupStore
    } else {
      let backupStore = BackupStore(
        walletService: servicesAssembly.walletsService()
      )
      _backupStore = backupStore
      return backupStore
    }
  }
  
  private weak var _securityStore: SecurityStore?
  public var securityStore: SecurityStore {
    if let securityStore = _securityStore {
      return securityStore
    } else {
      let securityStore = SecurityStore(securityService: servicesAssembly.securityService())
      _securityStore = securityStore
      return securityStore
    }
  }
  
  private weak var _setupStore: SetupStore?
  var setupStore: SetupStore {
    if let setupStore = _setupStore {
      return setupStore
    } else {
      let setupStore = SetupStore(setupService: servicesAssembly.setupService())
      _setupStore = setupStore
      return setupStore
    }
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
}

private class Weak<T: AnyObject> {
  weak var value : T?
  init (value: T) {
    self.value = value
  }
}

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
  
  private weak var _walletTotalBalanceStore: WalletTotalBalanceStore?
  func walletTotalBalanceStore(walletsStore: WalletsStore) -> WalletTotalBalanceStore {
    if let _walletTotalBalanceStore {
      return _walletTotalBalanceStore
    }
    let walletTotalBalanceStore = WalletTotalBalanceStore(
      walletsStore: walletsStore,
      walletBalanceStore: walletBalanceStore,
      tonRatesStore: tonRatesStore,
      currencyStore: currencyStore,
      totalBalanceService: servicesAssembly.totalBalanceService()
    )
    _walletTotalBalanceStore = walletTotalBalanceStore
    return walletTotalBalanceStore
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
  var securityStore: SecurityStore {
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
  
  private weak var _backgroundUpdateStore: BackgroundUpdateStore?
  var backgroundUpdateStore: BackgroundUpdateStore {
    if let backgroundUpdateStore = _backgroundUpdateStore {
      return backgroundUpdateStore
    } else {
      let backgroundUpdateStore = BackgroundUpdateStore(
        streamingAPI: apiAssembly.streamingTonAPIClient()
      )
      _backgroundUpdateStore = backgroundUpdateStore
      return backgroundUpdateStore
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

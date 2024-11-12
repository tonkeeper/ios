import Foundation
import TonSwift

public final class StoresAssembly {
  private let apiAssembly: APIAssembly
  private let coreAssembly: CoreAssembly
  private let repositoriesAssembly: RepositoriesAssembly
  
  init(apiAssembly: APIAssembly,
       coreAssembly: CoreAssembly,
       repositoriesAssembly: RepositoriesAssembly) {
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
  
  private weak var _walletsStore: WalletsStore?
  public var walletsStore: WalletsStore {
    if let _walletsStore {
      return _walletsStore
    }
    let store = WalletsStore(keeperInfoStore: keeperInfoStore)
    _walletsStore = store
    return store
  }
  
  private weak var _balanceStore: BalanceStore?
  public var balanceStore: BalanceStore {
    if let _balanceStore {
      return _balanceStore
    }
    let store = BalanceStore(walletsStore: walletsStore,
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
        tonRatesStore: tonRatesStore,
        currencyStore: currencyStore

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
      tonRatesStore: tonRatesStore,
      currencyStore: currencyStore,
      stakingPoolsStore: stackingPoolsStore
    )
    _processedBalanceStore = store
    return store
  }
  
  private weak var _managedBalanceStore: ManagedBalanceStore?
  public var managedBalanceStore: ManagedBalanceStore {
    if let _managedBalanceStore {
      return _managedBalanceStore
    }
    let store = ManagedBalanceStore(
      balanceStore: processedBalanceStore,
      tokenManagementStore: tokenManagementStore
    )
    _managedBalanceStore = store
    return store
  }
  
  private weak var _totalBalanceStore: TotalBalanceStore?
  public var totalBalanceStore: TotalBalanceStore {
    if let _totalBalanceStore {
      return _totalBalanceStore
    }
    let store = TotalBalanceStore(managedBalanceStore: managedBalanceStore)
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

  private weak var _regionStore: RegionStore?
  public var regionStore: RegionStore {
    if let _regionStore {
      return _regionStore
    }
    let store = RegionStore(keeperInfoStore: keeperInfoStore)
    _regionStore = store
    return store
  }

  private weak var _tonRatesStore: TonRatesStore?
  public var tonRatesStore: TonRatesStore {
    if let tonRatesStoreV3 = _tonRatesStore {
      return tonRatesStoreV3
    } else {
      let tonRatesStore = TonRatesStore(
        repository: repositoriesAssembly.ratesRepository()
      )
      _tonRatesStore = tonRatesStore
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
  
  private var _walletNFTsManagedStores = [Wallet: Weak<WalletNFTsManagedStore>]()
  public func walletNFTsManagedStore(wallet: Wallet) -> WalletNFTsManagedStore {
    if let weakWrapper = _walletNFTsManagedStores[wallet],
       let store = weakWrapper.value {
      return store
    }
    let store = WalletNFTsManagedStore(
      wallet: wallet,
      walletNFTStore: walletNFTsStore,
      walletNFTsManagementStore: walletNFTsManagementStore(wallet: wallet)
    )
    _walletNFTsManagedStores[wallet] = Weak(value: store)
    return store
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
  
  private weak var _stackingPoolsStore: StakingPoolsStore?
  public var stackingPoolsStore: StakingPoolsStore {
    if let store = _stackingPoolsStore {
      return store
    } else {
      let store = StakingPoolsStore(
        walletsStore: walletsStore,
        repository: repositoriesAssembly.stakingPoolsInfoRepository()
      )
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

  private weak var _appSettingsStore: AppSettingsStore?
  public var appSettingsStore: AppSettingsStore {
    if let appSettingsStore = _appSettingsStore {
      return appSettingsStore
    } else {
      let appSettingsStore = AppSettingsStore(keeperInfoStore: keeperInfoStore)
      _appSettingsStore = appSettingsStore
      return appSettingsStore
    }
  }
  
  private weak var _decryptedCommentStore: DecryptedCommentStore?
  public var decryptedCommentStore: DecryptedCommentStore {
    if let decryptedCommentStore = _decryptedCommentStore {
      return decryptedCommentStore
    } else {
      let decryptedCommentStore = DecryptedCommentStore()
      _decryptedCommentStore = decryptedCommentStore
      return decryptedCommentStore
    }
  }
}

class Weak<T: AnyObject> {
  weak var value : T?
  init (value: T) {
    self.value = value
  }
}

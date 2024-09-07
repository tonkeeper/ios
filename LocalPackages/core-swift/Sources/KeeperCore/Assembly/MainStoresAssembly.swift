import Foundation
import TonSwift

public final class MainStoresAssembly {
  
  private let walletsAssembly: WalletAssembly
  private let repositoriesAssembly: RepositoriesAssembly
  private let servicesAssembly: ServicesAssembly
  private let storesAssembly: StoresAssembly
  private let apiAssembly: APIAssembly
  
  init(walletsAssembly: WalletAssembly,
       repositoriesAssembly: RepositoriesAssembly,
       servicesAssembly: ServicesAssembly,
       storesAssembly: StoresAssembly,
       apiAssembly: APIAssembly) {
    self.walletsAssembly = walletsAssembly
    self.repositoriesAssembly = repositoriesAssembly
    self.servicesAssembly = servicesAssembly
    self.storesAssembly = storesAssembly
    self.apiAssembly = apiAssembly
  }
  
  private weak var _balanceStore: BalanceStore?
  public var balanceStore: BalanceStore {
    if let _balanceStore {
      return _balanceStore
    }
    let store = BalanceStore(walletsStore: walletsAssembly.walletsStore,
                               repository: repositoriesAssembly.walletBalanceRepositoryV2()
    )
    _balanceStore = store
    return store
  }
//  
//  private weak var _accountNftsStore: AccountNFTsStore?
//  public var accountNftsStore: AccountNFTsStore {
//    if let _accountNftsStore {
//      return _accountNftsStore
//    }
//    let accountNftsStore = AccountNFTsStore(walletsStore: walletsAssembly.walletsStore,
//                                            repository: repositoriesAssembly.accountsNftRepository())
//    _accountNftsStore = accountNftsStore
//    return accountNftsStore
//  }
  
  private var _accountNFTsManagementStore = [Wallet: Weak<AccountNFTsManagementStore>]()
  public func accountNFTsManagementStore(wallet: Wallet) -> AccountNFTsManagementStore {
    if let weakWrapper = _accountNFTsManagementStore[wallet],
       let store = weakWrapper.value {
      return store
    }
    let store = AccountNFTsManagementStore(
      wallet: wallet,
      accountNFTsManagementRepository: repositoriesAssembly.accountNFTsManagementRepository()
    )
    _accountNFTsManagementStore[wallet] = Weak(value: store)
    return store
  }
  
  private weak var _backgroundUpdateUpdater: BackgroundUpdateUpdater?
  public var backgroundUpdateUpdater: BackgroundUpdateUpdater {
    if let backgroundUpdateUpdater = _backgroundUpdateUpdater {
      return backgroundUpdateUpdater
    } else {
      let backgroundUpdateUpdater = BackgroundUpdateUpdater(
        backgroundUpdateStore: storesAssembly.backgroundUpdateStore,
        walletsStore: storesAssembly.walletsStore,
        streamingAPI: apiAssembly.streamingTonAPIClient()
      )
      _backgroundUpdateUpdater = backgroundUpdateUpdater
      return backgroundUpdateUpdater
    }
  }
  
  private weak var _backgroundUpdateStore: BackgroundUpdateStore?
  public var backgroundUpdateStore: BackgroundUpdateStore {
    if let backgroundUpdateStore = _backgroundUpdateStore {
      return backgroundUpdateStore
    } else {
      let backgroundUpdateStore = BackgroundUpdateStore()
      _backgroundUpdateStore = backgroundUpdateStore
      return backgroundUpdateStore
    }
  }
}

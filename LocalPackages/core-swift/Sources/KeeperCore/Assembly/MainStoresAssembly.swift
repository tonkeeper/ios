import Foundation
import TonSwift

public final class MainStoresAssembly {
  
  private let walletsAssembly: WalletAssembly
  private let repositoriesAssembly: RepositoriesAssembly
  
  init(walletsAssembly: WalletAssembly,
       repositoriesAssembly: RepositoriesAssembly) {
    self.walletsAssembly = walletsAssembly
    self.repositoriesAssembly = repositoriesAssembly
  }
  
  private weak var _walletsBalanceStore: WalletsBalanceStoreV2?
  public var walletsBalanceStore: WalletsBalanceStoreV2 {
    if let _walletsBalanceStore {
      return _walletsBalanceStore
    }
    let store = WalletsBalanceStoreV2(walletsStore: walletsAssembly.walletsStoreV2,
                                      repository: repositoriesAssembly.walletBalanceRepositoryV2()
    )
    _walletsBalanceStore = store
    return store
  }
}

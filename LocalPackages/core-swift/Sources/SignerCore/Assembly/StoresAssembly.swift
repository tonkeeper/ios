import Foundation
import TonSwift

public final class StoresAssembly {
  
  private let servicesAssembly: ServicesAssembly
  private let coreAssembly: CoreAssembly
  private let repositoriesAssembly: RepositoriesAssembly
  
  init(servicesAssembly: ServicesAssembly,
       coreAssembly: CoreAssembly,
       repositoriesAssembly: RepositoriesAssembly) {
    self.servicesAssembly = servicesAssembly
    self.coreAssembly = coreAssembly
    self.repositoriesAssembly = repositoriesAssembly
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
  
  private weak var _walletKeysStore: WalletKeysStore?
  var walletKeysStore: WalletKeysStore {
    if let walletKeysStore = _walletKeysStore {
      return walletKeysStore
    } else {
      let walletKeysStore = WalletKeysStore(walletKeysService: servicesAssembly.walletKeysService())
      _walletKeysStore = walletKeysStore
      return walletKeysStore
    }
  }
}

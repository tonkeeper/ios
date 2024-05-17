import Foundation

public final class ServicesAssembly {
  
  private let repositoriesAssembly: RepositoriesAssembly
  private let coreAssembly: CoreAssembly
  
  init(repositoriesAssembly: RepositoriesAssembly,
       coreAssembly: CoreAssembly) {
    self.repositoriesAssembly = repositoriesAssembly
    self.coreAssembly = coreAssembly
  }
  
  func securityService() -> SecurityService {
    SecurityServiceImplementation(
      signerInfoRepository: repositoriesAssembly.signerInfoRepository()
    )
  }
  
  func walletKeysService() -> WalletKeysService {
    WalletKeysServiceImplementation(
      signerInfoRepository: repositoriesAssembly.signerInfoRepository()
    )
  }
  
  public func signOutService() -> SignOutService {
    SignOutServiceImplementation(
      signerInfoRepository: repositoriesAssembly.signerInfoRepository(),
      mnemonicsRepository: repositoriesAssembly.mnemonicsRepository()
    )
  }
}

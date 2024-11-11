import Foundation

public final class WalletsUpdateAssembly {
  
  public let storesAssembly: StoresAssembly
  public let servicesAssembly: ServicesAssembly
  public let repositoriesAssembly: RepositoriesAssembly
  public let formattersAssembly: FormattersAssembly
  public let secureAssembly: SecureAssembly
  
  init(storesAssembly: StoresAssembly,
       servicesAssembly: ServicesAssembly,
       repositoriesAssembly: RepositoriesAssembly,
       formattersAssembly: FormattersAssembly,
       secureAssembly: SecureAssembly) {
    self.storesAssembly = storesAssembly
    self.servicesAssembly = servicesAssembly
    self.repositoriesAssembly = repositoriesAssembly
    self.formattersAssembly = formattersAssembly
    self.secureAssembly = secureAssembly
  }
  
  public func walletAddController() -> WalletAddController {
    WalletAddController(
      walletsStore: storesAssembly.walletsStore,
      tonProofTokenService: servicesAssembly.tonProofTokenService(), 
      mnemonicsRepositoty: secureAssembly.mnemonicsRepository()
    )
  }
  
  public func walletImportController() -> WalletImportController {
    WalletImportController(
      activeWalletService: servicesAssembly.activeWalletsService(),
      currencyService: servicesAssembly.currencyService()
    )
  }

  public func watchOnlyWalletAddressInputController() -> WatchOnlyWalletAddressInputController {
    WatchOnlyWalletAddressInputController(
      addressResolver: AddressResolver(dnsService: servicesAssembly.dnsService())
    )
  }
}

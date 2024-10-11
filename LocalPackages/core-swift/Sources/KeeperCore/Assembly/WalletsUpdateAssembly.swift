import Foundation

public final class WalletsUpdateAssembly {
  
  public let storesAssembly: StoresAssembly
  public let servicesAssembly: ServicesAssembly
  public let repositoriesAssembly: RepositoriesAssembly
  public let formattersAssembly: FormattersAssembly
  public let rnAssembly: RNAssembly
  
  init(storesAssembly: StoresAssembly,
       servicesAssembly: ServicesAssembly,
       repositoriesAssembly: RepositoriesAssembly,
       formattersAssembly: FormattersAssembly,
       rnAssembly: RNAssembly) {
    self.storesAssembly = storesAssembly
    self.servicesAssembly = servicesAssembly
    self.repositoriesAssembly = repositoriesAssembly
    self.formattersAssembly = formattersAssembly
    self.rnAssembly = rnAssembly
  }
  
  public func walletAddController() -> WalletAddController {
    WalletAddController(
      walletsStore: storesAssembly.walletsStore,
      tonProofTokenService: servicesAssembly.tonProofTokenService(),
      mnemonicsRepositoty: repositoriesAssembly.mnemonicsRepository()
    )
  }
  
  public func walletImportController() -> WalletImportController {
    WalletImportController(activeWalletService: servicesAssembly.activeWalletsService(), currencyService: servicesAssembly.currencyService())
  }
  
  public func walletUpdateController() -> WalletEditController {
    WalletEditController(walletsStore: storesAssembly.walletsStore)
  }
  
  public func watchOnlyWalletAddressInputController() -> WatchOnlyWalletAddressInputController {
    WatchOnlyWalletAddressInputController(addressResolver: AddressResolver(dnsService: servicesAssembly.dnsService()))
  }
}

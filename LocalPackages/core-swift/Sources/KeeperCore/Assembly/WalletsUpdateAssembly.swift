import Foundation

public final class WalletsUpdateAssembly {
  
  public let servicesAssembly: ServicesAssembly
  public let repositoriesAssembly: RepositoriesAssembly
  private let formattersAssembly: FormattersAssembly
  
  init(servicesAssembly: ServicesAssembly,
       repositoriesAssembly: RepositoriesAssembly,
       formattersAssembly: FormattersAssembly) {
    self.servicesAssembly = servicesAssembly
    self.repositoriesAssembly = repositoriesAssembly
    self.formattersAssembly = formattersAssembly
  }
  
  public lazy var walletsStoreUpdate: WalletsStoreUpdate = {
    WalletsStoreUpdate(walletsService: servicesAssembly.walletsService())
  }()
  
  public func walletAddController() -> WalletAddController {
    WalletAddController(
      walletsStoreUpdate: walletsStoreUpdate,
      mnemonicsRepositoty: repositoriesAssembly.mnemonicsRepository()
    )
  }
  
  public func walletImportController() -> WalletImportController {
    WalletImportController(activeWalletService: servicesAssembly.activeWalletsService(), currencyService: servicesAssembly.currencyService())
  }
  
  public func walletUpdateController() -> WalletEditController {
    WalletEditController(walletsStoreUpdate: walletsStoreUpdate)
  }
  
  public func watchOnlyWalletAddressInputController() -> WatchOnlyWalletAddressInputController {
    WatchOnlyWalletAddressInputController(addressResolver: AddressResolver(dnsService: servicesAssembly.dnsService()))
  }
  
  public func chooseWalletController(activeWalletModels: [ActiveWalletModel], configuration: ChooseWalletsController.Configuration) -> ChooseWalletsController {
    ChooseWalletsController(
      activeWalletModels: activeWalletModels,
      amountFormatter: formattersAssembly.amountFormatter,
      configuration: configuration
    )
  }
}

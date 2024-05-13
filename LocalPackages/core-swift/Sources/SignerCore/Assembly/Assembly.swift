import Foundation

public final class Assembly {
  let coreAssembly: CoreAssembly
  public lazy var repositoriesAssembly = RepositoriesAssembly(coreAssembly: coreAssembly)
  private lazy var servicesAssembly = ServicesAssembly(
    repositoriesAssembly: repositoriesAssembly,
    coreAssembly: coreAssembly
  )
  public lazy var storesAssembly = StoresAssembly(
    servicesAssembly: servicesAssembly,
    coreAssembly: coreAssembly,
    repositoriesAssembly: repositoriesAssembly
  )

  public lazy var formattersAssembly = FormattersAssembly()
  
  public init() {
    self.coreAssembly = CoreAssembly()
  }
  
  public func rootController() -> RootController {
    RootController(walletKeysStore: storesAssembly.walletKeysStore)
  }
  
  public func mainController() -> MainController {
    MainController(deeplinkParser: DefaultDeeplinkParser(parsers: [
      TonsignDeeplinkParser()
    ]))
  }
  
  public func keysAddController() -> KeysAddController {
    KeysAddController(
      walletKeysStore: storesAssembly.walletKeysStore,
      mnemonicsRepositoty: repositoriesAssembly.mnemonicsRepository()
    )
  }
  
  public func keysEditController() -> KeysEditController {
    KeysEditController(
      walletKeysStore: storesAssembly.walletKeysStore,
      mnemonicsRepositoty: repositoriesAssembly.mnemonicsRepository()
    )
  }
  
  public func walletKeysListController() -> WalletKeysListController {
    WalletKeysListController(walletKeysStore: storesAssembly.walletKeysStore)
  }
  
  public func walletKeyDetailsController(walletKey: WalletKey) -> WalletKeyDetailsController {
    WalletKeyDetailsController(
      walletKey: walletKey,
      walletKeysStore: storesAssembly.walletKeysStore,
      mnemonicsRepository: repositoriesAssembly.mnemonicsRepository()
    )
  }
  
  public func recoveryPhraseController(walletKey: WalletKey, password: String) -> RecoveryPhraseController {
    RecoveryPhraseController(
      key: walletKey,
      mnemonicsRepository: repositoriesAssembly.mnemonicsRepository(),
      password: password
    )
  }
  
  public func scannerController() -> ScannerController {
    ScannerController()
  }
  
  public func signConfirmationController(model: TonSignModel, walletKey: WalletKey) -> SignConfirmationController {
    SignConfirmationController(
      model: model,
      walletKey: walletKey,
      mnemonicsRepository: repositoriesAssembly.mnemonicsRepository(),
      deeplinkGenerator: PublishDeeplinkGenerator(),
      amountFormatter: formattersAssembly.amountFormatter
    )
  }
  
  public func signQRController(hexBody: String, walletKey: WalletKey, url: URL) -> SignQRController {
    SignQRController(
      hexBody: hexBody,
      walletKey: walletKey,
      url: url
    )
  }
}


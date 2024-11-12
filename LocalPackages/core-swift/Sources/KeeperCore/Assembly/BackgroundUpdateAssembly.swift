import Foundation

public final class BackgroundUpdateAssembly {
  
  private let apiAssembly: APIAssembly
  private let storesAssembly: StoresAssembly
  private let coreAssembly: CoreAssembly
  
  init(apiAssembly: APIAssembly,
       storesAssembly: StoresAssembly,
       coreAssembly: CoreAssembly) {
    self.apiAssembly = apiAssembly
    self.storesAssembly = storesAssembly
    self.coreAssembly = coreAssembly
  }

  private weak var _backgroundUpdate: BackgroundUpdate?
  public var backgroundUpdate: BackgroundUpdate {
    if let backgroundUpdate = _backgroundUpdate {
      return backgroundUpdate
    } else {
      let backgroundUpdate = BackgroundUpdate(
        walletStore: storesAssembly.walletsStore) { [apiAssembly] wallet in
          WalletBackgroundUpdate(wallet: wallet,
                                 streamingAPIProvider: apiAssembly.streaminAPIProvider)
        }
      _backgroundUpdate = backgroundUpdate
      return backgroundUpdate
    }
  }
}

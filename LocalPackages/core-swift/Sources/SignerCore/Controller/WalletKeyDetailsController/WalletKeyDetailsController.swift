import Foundation

public final class WalletKeyDetailsController {
  
  public var didUpdateWalletKey: ((WalletKey) -> Void)?
  
  public private(set) var walletKey: WalletKey
  private let walletKeysStore: WalletKeysStore
  
  init(walletKey: WalletKey,
       walletKeysStore: WalletKeysStore) {
    self.walletKey = walletKey
    self.walletKeysStore = walletKeysStore
  }
  
  public func start() {
    _ = walletKeysStore.addEventObserver(self) { observer, event in
      switch event {
      case .didUpdateKeyName(let walletKey):
        self.walletKey = walletKey
        observer.didUpdateWalletKey?(walletKey)
      default:
        break
      }
    }
    didUpdateWalletKey?(walletKey)
  }
  
  public func exportDeeplinkUrl() -> URL? {
    ExportDeeplinkGenerator().generateDeeplink(network: .ton, key: walletKey)
  }
  
  public func deleteKey() throws {
    try walletKeysStore.deleteKey(walletKey)
  }
}

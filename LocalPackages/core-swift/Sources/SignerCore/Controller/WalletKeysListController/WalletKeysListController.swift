import Foundation

public final class WalletKeysListController {
  
  public var didUpdateKeys: (([WalletKey]) -> Void)?
  
  private let walletKeysStore: WalletKeysStore
  
  init(walletKeysStore: WalletKeysStore) {
    self.walletKeysStore = walletKeysStore
  }
  
  public func start() {
    _ = walletKeysStore.addEventObserver(self) { observer, event in
      switch event {
      case .didAddKey:
        observer.didUpdateWalletKeys()
      case .didUpdateKeyName:
        observer.didUpdateWalletKeys()
      case .didDeleteKey:
        observer.didUpdateWalletKeys()
      default: break
      }
    }
    
    didUpdateKeys?(walletKeysStore.getWalletKeys())
  }
}

private extension WalletKeysListController {
  func didUpdateWalletKeys() {
    didUpdateKeys?(walletKeysStore.getWalletKeys())
  }
}

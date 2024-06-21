import Foundation

public struct WalletsState: Equatable {
  public let wallets: [Wallet]
  public let activeWallet: Wallet
  
  public init(wallets: [Wallet], 
              activeWallet: Wallet) {
    self.wallets = wallets
    self.activeWallet = activeWallet
  }
}

public final class WalletsStoreV2: Store<WalletsState> {
  
  private let keeperInfoStore: KeeperInfoStore
  
  init(state: WalletsState, keeperInfoStore: KeeperInfoStore) {
    self.keeperInfoStore = keeperInfoStore
    super.init(item: state)
    keeperInfoStore.addObserver(
      self,
      notifyOnAdded: false) { observer, keeperInfo in
        observer.didUpdateKeeperInfo(keeperInfo)
      }
  }
}

private extension WalletsStoreV2 {
  func didUpdateKeeperInfo(_ keeperInfo: KeeperInfo?) {
    guard let keeperInfo else { return }
    Task {
      await updateItem { state in
        let newState = WalletsState(
          wallets: keeperInfo.wallets,
          activeWallet: keeperInfo.currentWallet
        )
        return newState
      }
    }
  }
}

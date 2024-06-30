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
    super.init(state: state)
    keeperInfoStore.addObserver(
      self,
      notifyOnAdded: false) { observer, keeperInfo, _ in
        observer.didUpdateKeeperInfo(keeperInfo)
      }
  }
}

private extension WalletsStoreV2 {
  func didUpdateKeeperInfo(_ keeperInfo: KeeperInfo?) {
    guard let keeperInfo else { return }
    Task {
      await updateState { walletsState in
        let newWalletsState = WalletsState(
          wallets: keeperInfo.wallets,
          activeWallet: keeperInfo.currentWallet
        )
        return StateUpdate(newState: newWalletsState)
      }
    }
  }
}

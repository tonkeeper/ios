import Foundation

public struct WalletsState: Equatable {
  public let wallets: [Wallet]
  public let activeWallet: Wallet
  
  public init(wallets: [Wallet], 
              activeWallet: Wallet) {
    self.wallets = wallets
    self.activeWallet = activeWallet
  }
  
  static func state(keeperInfo: KeeperInfo) -> WalletsState {
    WalletsState(wallets: keeperInfo.wallets, activeWallet: keeperInfo.currentWallet)
  }
}

public final class WalletsStore: StoreUpdated<WalletsState> {
  
  private let keeperInfoStore: KeeperInfoStore
  private let getInitialStateClosure: () -> WalletsState
  
  init(state: WalletsState, keeperInfoStore: KeeperInfoStore) {
    self.keeperInfoStore = keeperInfoStore
    self.getInitialStateClosure = {
      state
    }
    super.init(state: state)
    keeperInfoStore.addObserver(
      self,
      notifyOnAdded: false) { observer, keeperInfo, _ in
        observer.didUpdateKeeperInfo(keeperInfo)
      }
  }
  
  public override func getInitialState() -> WalletsState {
    getInitialStateClosure()
  }
}

private extension WalletsStore {
  func didUpdateKeeperInfo(_ keeperInfo: KeeperInfo?) {
    guard let keeperInfo else { return }
    updateState { _ in
      StateUpdate(newState: WalletsState.state(keeperInfo: keeperInfo))
    }
  }
}

import Foundation

public final class CollectiblesController {
  
  public var didUpdateIsConnecting: ((Bool) -> Void)?
  public var didUpdateActiveWallet: (() -> Void)?
  public var didUpdateIsEmpty: ((Bool) -> Void)?

  private let walletsStore: WalletsStore
  private let backgroundUpdateStore: BackgroundUpdateStore
  private let nftsStore: NftsStore
  
  init(walletsStore: WalletsStore,
       backgroundUpdateStore: BackgroundUpdateStore,
       nftsStore: NftsStore) {
    self.walletsStore = walletsStore
    self.backgroundUpdateStore = backgroundUpdateStore
    self.nftsStore = nftsStore
  }
  
  public var wallet: Wallet {
    walletsStore.getState().activeWallet
  }
  
  public func start() async {
    walletsStore.addObserver(self, notifyOnAdded: false) { observer, newState, oldState in
      guard newState.activeWallet.id != oldState.activeWallet.id else { return }
      Task { await observer.didChangeActiveWallet() }
    }
    
    backgroundUpdateStore.addObserver(self, notifyOnAdded: false) { observer, newState, oldState in
      observer.handleBackgroundUpdateState(newState)
    }

    _ = await nftsStore.addEventObserver(self) { observer, event in
      switch event {
      case .nftsUpdate(let nfts, let wallet):
        guard (try? wallet.friendlyAddress) == (try? observer.wallet.friendlyAddress) else { return }
        observer.didUpdateIsEmpty?(nfts.isEmpty)
      }
    }
    
    let nfts = await nftsStore.getNfts(wallet: wallet)
    didUpdateIsEmpty?(nfts.isEmpty)
  }
  
  public func updateConnectingState() async {
    let state = await backgroundUpdateStore.getState()
    handleBackgroundUpdateState(state)
  }
}

private extension CollectiblesController {
  func didChangeActiveWallet() async {
    guard let address = try? wallet.address else { return }
    let nfts = await nftsStore.getNfts(wallet: wallet)
    didUpdateActiveWallet?()
    didUpdateIsEmpty?(nfts.isEmpty)
  }
  
  func handleBackgroundUpdateState(_ state: BackgroundUpdateStore.State) {
    let isConnecting: Bool
    switch state {
    case .connecting:
      isConnecting = true
    case .connected:
      isConnecting = false
    case .disconnected:
      isConnecting = true
    case .noConnection:
      isConnecting = false
    }
    didUpdateIsConnecting?(isConnecting)
  }
}

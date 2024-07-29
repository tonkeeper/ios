import Foundation

public final class HistoryController {
  
  public var didUpdateWallet: (() -> Void)?
  public var didUpdateIsConnecting: ((Bool) -> Void)?
  
  private var walletsStoreObservationToken: ObservationToken?
  
  private let walletsStore: WalletsStore
  private let backgroundUpdateStore: BackgroundUpdateStore
  
  init(walletsStore: WalletsStore,
       backgroundUpdateStore: BackgroundUpdateStore) {
    self.walletsStore = walletsStore
    self.backgroundUpdateStore = backgroundUpdateStore
    
    backgroundUpdateStore.addObserver(self, notifyOnAdded: true) { observer, newState, oldState in
      observer.handleBackgroundUpdateState(newState)
    }
    
    walletsStore.addObserver(self, notifyOnAdded: false) { observer, newState, oldState in
      observer.didUpdateWallet?()
    }
  }
  
  deinit {
    walletsStoreObservationToken?.cancel()
  }
  
  public var wallet: Wallet {
    walletsStore.getState().activeWallet
  }
  
  public var isConnecting: Bool {
    let state = backgroundUpdateStore.getState()
    return createIsConnecting(state)
  }
}

extension HistoryController {
  func createIsConnecting(_ state: BackgroundUpdateStore.State) -> Bool {
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
    return isConnecting
  }
  
  func handleBackgroundUpdateState(_ state: BackgroundUpdateStore.State) {
    let isConnecting = createIsConnecting(state)
    didUpdateIsConnecting?(isConnecting)
  }
}

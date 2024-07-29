import Foundation

public final class HistoryController {
  
  public var didUpdateWallet: (() -> Void)?
  public var didUpdateIsConnecting: ((Bool) -> Void)?
  
  private var walletsStoreObservationToken: ObservationToken?
  
  private let walletsStore: WalletsStore
  private let backgroundUpdateStore: BackgroundUpdateStoreV2
  
  init(walletsStore: WalletsStore,
       backgroundUpdateStore: BackgroundUpdateStoreV2) {
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
  func createIsConnecting(_ state: BackgroundUpdateStoreV2.State) -> Bool {
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
  
  func handleBackgroundUpdateState(_ state: BackgroundUpdateStoreV2.State) {
    let isConnecting = createIsConnecting(state)
    didUpdateIsConnecting?(isConnecting)
  }
}

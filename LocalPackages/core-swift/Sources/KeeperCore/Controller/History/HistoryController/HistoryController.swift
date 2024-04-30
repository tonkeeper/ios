import Foundation

public final class HistoryController {
  
  public var didUpdateWallet: (() -> Void)?
  public var didUpdateIsConnecting: ((Bool) -> Void)?
  
  private var walletsStoreObservationToken: ObservationToken?
  private var backgroundUpdateStoreObservationToken: ObservationToken?
  
  private let walletsStore: WalletsStore
  private let backgroundUpdateStore: BackgroundUpdateStore
  
  init(walletsStore: WalletsStore,
       backgroundUpdateStore: BackgroundUpdateStore) {
    self.walletsStore = walletsStore
    self.backgroundUpdateStore = backgroundUpdateStore
    
    Task {
      walletsStoreObservationToken = walletsStore.addEventObserver(self) { observer, event in
        observer.didGetWalletsStoreEvent(event)
      }
      
      backgroundUpdateStoreObservationToken = await backgroundUpdateStore.addEventObserver(self) { observer, event in
        switch event {
        case .didUpdateState(let backgroundUpdateState):
          observer.handleBackgroundUpdateState(backgroundUpdateState)
        case .didReceiveUpdateEvent:
          break
        }
      }
    }
  }
  
  deinit {
    walletsStoreObservationToken?.cancel()
    backgroundUpdateStoreObservationToken?.cancel()
  }
  
  public var wallet: Wallet {
    walletsStore.activeWallet
  }
  
  public func updateConnectingState() {
    Task {
      let state = await backgroundUpdateStore.state
      handleBackgroundUpdateState(state)
    }
  }
}

extension HistoryController {
  func didGetWalletsStoreEvent(_ event: WalletsStore.Event) {
    switch event {
    case .didUpdateActiveWallet:
      didUpdateWallet?()
    default:
      break
    }
  }
  
  func handleBackgroundUpdateState(_ state: BackgroundUpdateState) {
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

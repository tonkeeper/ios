import Foundation
import KeeperCore

final class RootCoordinatorStateManager {
  enum State: Equatable {
    case onboarding
    case main
    
    static func ==(lhs: State, rhs: State) -> Bool {
      switch (lhs, rhs) {
      case (.onboarding, .onboarding):
        return true
      case (.main, .main):
        return true
      default:
        return false
      }
    }
  }
  
  var didUpdateState: ((State) -> Void)?
  var state: State {
    get {
      guard let _state else {
        let state = calculateState(walletsStoreState: walletsStore.getState())
        _state = state
        return state
      }
      return _state
    }
    set {
      guard newValue != _state else { return }
      _state = newValue
      didUpdateState?(newValue)
    }
  }
  private var _state: State?
  
  private let walletsStore: WalletsStoreV3
  
  init(walletsStore: WalletsStoreV3) {
    self.walletsStore = walletsStore
    walletsStore.addObserver(self) { observer, event in
      switch event {
      case .didDeleteWallet, .didAddWallets, .didDeleteAll:
        DispatchQueue.main.async {
          self.state = observer.calculateState(walletsStoreState: walletsStore.getState())
        }
      default: break
      }
    }
  }

  private func calculateState(walletsStoreState: WalletsStoreV3.State) -> State {
    switch walletsStoreState {
    case .empty:
      return .onboarding
    case .wallets:
      return .main
    }
  }
}

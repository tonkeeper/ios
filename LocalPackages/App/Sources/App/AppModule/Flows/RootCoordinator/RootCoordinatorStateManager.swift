import Foundation
import KeeperCore

final class RootCoordinatorStateManager {
  enum State: Equatable {
    case onboarding
    case main(walletsState: WalletsState)
    
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
        let keeperInfo = keeperInfoStore.getState()
        let state = calculateState(keeperInfo: keeperInfo)
        self._state = state
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
  
  private let keeperInfoStore: KeeperInfoStore
  
  init(keeperInfoStore: KeeperInfoStore) {
    self.keeperInfoStore = keeperInfoStore
    keeperInfoStore.addObserver(self, notifyOnAdded: false) { observer, keeperInfo, _ in
      DispatchQueue.main.async {
        let state = observer.calculateState(keeperInfo: keeperInfo)
        self.state = state
      }
    }
  }
  
  private func calculateState(keeperInfo: KeeperInfo?) -> State {
    if let keeperInfo {
      let walletsState = WalletsState(wallets: keeperInfo.wallets,
                                      activeWallet: keeperInfo.currentWallet)
      return .main(walletsState: walletsState)
    } else {
      return .onboarding
    }
  }
}

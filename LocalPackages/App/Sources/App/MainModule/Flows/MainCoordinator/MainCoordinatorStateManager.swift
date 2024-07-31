import Foundation
import KeeperCore

final class MainCoordinatorStateManager {
  
  struct State: Equatable {
    enum Tab: Equatable {
      case wallet
      case history
      case browser
      case purchases
    }
    
    let tabs: [Tab]
  }
  
  var didUpdateState: ((State) -> Void)?
  
  
  var state: State {
    get {
      guard let _state else {
        let walletsState = walletsStore.getState()
        let state = createState(walletsState: walletsState)
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
  
  private let walletsStore: WalletsStore
  
  init(walletsStore: WalletsStore) {
    self.walletsStore = walletsStore
    walletsStore.addObserver(
      self,
      notifyOnAdded: false) { observer, walletsState, _ in
        DispatchQueue.main.async {
          let state = observer.createState(walletsState: walletsState)
          self.state = state
        }
      }
  }

  private func createState(walletsState: WalletsState) -> State {
    var tabs = [State.Tab]()
    tabs.append(.wallet)
    tabs.append(.history)
    if walletsState.activeWallet.isBrowserAvailable {
      tabs.append(.browser)
    }
    tabs.append(.purchases)
    
    let state = State(tabs: tabs)
    return state
  }
}

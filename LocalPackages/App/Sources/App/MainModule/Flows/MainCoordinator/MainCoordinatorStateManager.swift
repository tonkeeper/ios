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
  
  private var state = State(tabs: []) {
    didSet {
      guard state != oldValue else { return }
      didUpdateState?(state)
      didUpdateState = nil
    }
  }
  
  private var walletsState: WalletsState? {
    didSet {
      guard walletsState != oldValue else { return }
      updateState()
    }
  }
 
  private let walletsStore: WalletsStore
  
  init(walletsStore: WalletsStore) {
    self.walletsStore = walletsStore
    walletsStore.addObserver(
      self,
      notifyOnAdded: true) { observer, walletsState, _ in
        DispatchQueue.main.async {
          observer.walletsState = walletsState
        }
      }
  }

  private func updateState() {
    guard let activeWallet = walletsState?.activeWallet else { return }
    
    var tabs = [State.Tab]()
    tabs.append(.wallet)
    tabs.append(.history)
    if activeWallet.isBrowserAvailable {
      tabs.append(.browser)
    }
    tabs.append(.purchases)
    
    let state = State(tabs: tabs)
    didUpdateState?(state)
  }
}

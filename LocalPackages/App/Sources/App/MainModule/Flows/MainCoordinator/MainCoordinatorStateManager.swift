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
  private let walletsStore: WalletsStore
  
  init(walletsStore: WalletsStore) {
    self.walletsStore = walletsStore
    walletsStore.addObserver(self) { observer, event in
      switch event {
      case .didChangeActiveWallet:
        DispatchQueue.main.async {
          guard let state = try? observer.createState(activeWallet: walletsStore.getActiveWallet()) else { return }
          observer.didUpdateState?(state)
        }
      default: break
      }
    }
  }
  
  func getState() throws -> State {
    let state = try createState(activeWallet: walletsStore.getActiveWallet())
    return state
  }

  private func createState(activeWallet: Wallet) -> State {
    var tabs = [State.Tab]()
    tabs.append(.wallet)
    tabs.append(.history)
    if activeWallet.isBrowserAvailable {
      tabs.append(.browser)
    }
    tabs.append(.purchases)
    
    let state = State(tabs: tabs)
    return state
  }
}

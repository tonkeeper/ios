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
  private(set) var state: State? {
    didSet {
      guard let state,
      state != oldValue else { return }
      didUpdateState?(state)
    }
  }
  
  private var keeperInfo: KeeperInfo? {
    didSet {
      didUpdateKeeperInfo()
    }
  }

  private let keeperInfoStore: KeeperInfoStore
  
  init(keeperInfoStore: KeeperInfoStore) {
    self.keeperInfoStore = keeperInfoStore
    keeperInfoStore.addObserver(self, notifyOnAdded: true) { observer, keeperInfo, _ in
      DispatchQueue.main.async {
        observer.keeperInfo = keeperInfo
      }
    }
  }

  private func didUpdateKeeperInfo() {
    updateState()
  }
  
  private func updateState() {
    if let keeperInfo {
      let walletsState = WalletsState(wallets: keeperInfo.wallets,
                                      activeWallet: keeperInfo.currentWallet)
      self.state = .main(walletsState: walletsState)
    } else {
      self.state = .onboarding
    }
  }
}

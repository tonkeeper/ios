import Foundation

public final class RootController {
  public enum State {
    case onboarding
    case main
  }
  
  public var didUpdateState: ((State) -> Void)?
  
  private let walletKeysStore: WalletKeysStore
  
  init(walletKeysStore: WalletKeysStore) {
    self.walletKeysStore = walletKeysStore
  }
  
  public func start() {
    _ = walletKeysStore.addEventObserver(self) { observer, event in
      switch event {
      case .didDeleteAll:
        observer.didUpdateState?(.onboarding)
      default:
        break
      }
    }
  }
  
  public func getState() -> State {
    if walletKeysStore.getWalletKeys().isEmpty {
      return .onboarding
    } else {
      return .main
    }
  }
}

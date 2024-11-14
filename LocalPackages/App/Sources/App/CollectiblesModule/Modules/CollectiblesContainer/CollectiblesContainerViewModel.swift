import UIKit
import KeeperCore

protocol CollectiblesContainerModuleOutput: AnyObject {
  var didChangeWallet: ((Wallet) -> Void)? { get set }
}

protocol CollectiblesContainerViewModel: AnyObject {
  func viewDidLoad()
}

final class CollectiblesContainerViewModelImplementation: CollectiblesContainerViewModel, CollectiblesContainerModuleOutput {
  
  // MARK: - CollectiblesContainerModuleOutput
  
  var didChangeWallet: ((Wallet) -> Void)?
  
  // MARK: - CollectiblesContainerModuleInput
  
  // MARK: - CollectiblesContainerViewModel
  
  func viewDidLoad() {
    walletsStore.addObserver(self) { observer, event in
      DispatchQueue.main.async {
        switch event {
        case .didChangeActiveWallet(let wallet):
          observer.didChangeWallet?(wallet)
        default: break
        }
      }
    }
    
    guard let wallet = try? walletsStore.activeWallet else { return }
    didChangeWallet?(wallet)
  }
  
  private let walletsStore: WalletsStore
  
  init(walletsStore: WalletsStore) {
    self.walletsStore = walletsStore
  }
}

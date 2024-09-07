import UIKit
import KeeperCore

protocol CollectiblesContainerModuleOutput: AnyObject {
  var didChangeWallet: ((Wallet) -> Void)? { get set }
}

protocol CollectiblesContainerModuleInput: AnyObject {
//  func set
//  func setWallet(_ wallet: Wallet)
}

protocol CollectiblesContainerViewModel: AnyObject {
  func viewDidLoad()
}

final class CollectiblesContainerViewModelImplementation: CollectiblesContainerViewModel, CollectiblesContainerModuleOutput, CollectiblesContainerModuleInput {
  
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
    
    guard let wallet = try? walletsStore.getActiveWallet() else { return }
    didChangeWallet?(wallet)
  }
  
  private let walletsStore: WalletsStoreV3
  
  init(walletsStore: WalletsStoreV3) {
    self.walletsStore = walletsStore
  }
}

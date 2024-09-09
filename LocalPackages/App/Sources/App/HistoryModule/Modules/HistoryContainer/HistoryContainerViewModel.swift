import UIKit
import KeeperCore

protocol HistoryContainerModuleOutput: AnyObject {
  var didChangeWallet: ((Wallet) -> Void)? { get set }
}

protocol HistoryContainerViewModel: AnyObject {
  func viewDidLoad()
}

final class HistoryContainerViewModelImplementation: HistoryContainerViewModel, HistoryContainerModuleOutput {
  
  // MARK: - HistoryContainerModuleOutput
  
  var didChangeWallet: ((Wallet) -> Void)?
  
  // MARK: - HistoryContainerModuleInput
  
  // MARK: - HistoryContainerViewModel
  
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
  
  private let walletsStore: WalletsStore
  
  init(walletsStore: WalletsStore) {
    self.walletsStore = walletsStore
  }
}

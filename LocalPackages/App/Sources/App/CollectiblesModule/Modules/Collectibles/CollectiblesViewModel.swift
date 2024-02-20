import Foundation
import TKCore
import TKUIKit
import KeeperCore

protocol CollectiblesModuleOutput: AnyObject {
  
}

protocol CollectiblesViewModel: AnyObject {
  var didUpdateListViewController: ((CollectiblesListViewController) -> Void)? { get set }
  var didUpdateIsConnecting: ((Bool) -> Void)? { get set }
  
  func viewDidLoad()
}

final class CollectiblesViewModelImplementation: CollectiblesViewModel, CollectiblesModuleOutput {
  
  // MARK: - CollectiblesModuleOutput
  
  var didUpdateListViewController: ((CollectiblesListViewController) -> Void)?
  
  // MARK: - CollectiblesViewModel
  
  var didUpdateIsConnecting: ((Bool) -> Void)?
  
  func viewDidLoad() {
    setupChildren()
    
    collectiblesController.didUpdateIsConnecting = { [weak self] isConnecting in
      guard let self = self else { return }
      Task { @MainActor in
        self.didUpdateIsConnecting?(isConnecting)
      }
    }
    
    collectiblesController.updateConnectingState()
  }
  
  // MARK: Dependencies
  
  private let collectiblesController: CollectiblesController
  private let listModuleProvider: (Wallet) -> MVVMModule<CollectiblesListViewController, CollectiblesListModuleOutput, Void>
  
  init(collectiblesController: CollectiblesController,
       listModuleProvider: @escaping (Wallet) -> MVVMModule<CollectiblesListViewController, CollectiblesListModuleOutput, Void>) {
    self.collectiblesController = collectiblesController
    self.listModuleProvider = listModuleProvider
  }
}

private extension CollectiblesViewModelImplementation {
  func setupChildren() {
    let listModule = listModuleProvider(collectiblesController.wallet)
    didUpdateListViewController?(listModule.view)
  }
}

import UIKit
import TKCore
import TKUIKit
import KeeperCore
import TonSwift

protocol CollectiblesModuleOutput: AnyObject {
  var didSelectNFT: ((NFT) -> Void)? { get set }
}

protocol CollectiblesViewModel: AnyObject {
  var didUpdateListViewController: ((CollectiblesListViewController) -> Void)? { get set }
  var didUpdateEmptyViewController: ((UIViewController) -> Void)? { get set }
  var didUpdateIsEmpty: ((Bool) -> Void)? { get set }
  var didUpdateIsConnecting: ((Bool) -> Void)? { get set }
  
  func viewDidLoad()
}

final class CollectiblesViewModelImplementation: CollectiblesViewModel, CollectiblesModuleOutput {
  
  // MARK: - CollectiblesModuleOutput
  
  var didSelectNFT: ((NFT) -> Void)?

  
  // MARK: - CollectiblesViewModel
  
  var didUpdateIsConnecting: ((Bool) -> Void)?
  var didUpdateListViewController: ((CollectiblesListViewController) -> Void)?
  var didUpdateEmptyViewController: ((UIViewController) -> Void)?
  var didUpdateIsEmpty: ((Bool) -> Void)?
  
  func viewDidLoad() {
    setupChildren()
    
    Task {
      collectiblesController.didUpdateIsConnecting = { [weak self] isConnecting in
        guard let self = self else { return }
        Task { @MainActor in
          self.didUpdateIsConnecting?(isConnecting)
        }
      }
      
      collectiblesController.didUpdateActiveWallet = { [weak self] in
        guard let self = self else { return }
        Task { @MainActor in
          self.setupChildren()
        }
      }
      
      collectiblesController.didUpdateIsEmpty = { [weak self] isEmpty in
        guard let self = self else { return }
        Task { @MainActor in
          self.didUpdateIsEmpty?(isEmpty)
        }
      }
      
      await collectiblesController.start()
      await collectiblesController.updateConnectingState()
    }
  }
  
  // MARK: Dependencies
  
  private let collectiblesController: CollectiblesController
  private let listModuleProvider: (Wallet) -> MVVMModule<CollectiblesListViewController, CollectiblesListModuleOutput, Void>
  private let emptyModuleProvider: (Wallet) -> MVVMModule<CollectiblesEmptyViewController, CollectiblesEmptyModuleOutput, Void>
  
  init(collectiblesController: CollectiblesController,
       listModuleProvider: @escaping (Wallet) -> MVVMModule<CollectiblesListViewController, CollectiblesListModuleOutput, Void>,
       emptyModuleProvider: @escaping (Wallet) -> MVVMModule<CollectiblesEmptyViewController, CollectiblesEmptyModuleOutput, Void>) {
    self.collectiblesController = collectiblesController
    self.listModuleProvider = listModuleProvider
    self.emptyModuleProvider = emptyModuleProvider
  }
}

private extension CollectiblesViewModelImplementation {
  func setupChildren() {
    let listModule = listModuleProvider(collectiblesController.wallet)
    listModule.output.didSelectNFT = { [weak self] nft in
      self?.didSelectNFT?(nft)
    }
    didUpdateListViewController?(listModule.view)
    
    let emptyModule = emptyModuleProvider(collectiblesController.wallet)
    
    didUpdateEmptyViewController?(emptyModule.view)
  }
}

import Foundation
import TKCore
import TKUIKit
import KeeperCore
import TonSwift

protocol CollectiblesModuleOutput: AnyObject {
  var didSelectNFT: ((NFT) -> Void)? { get set }
}

protocol CollectiblesViewModel: AnyObject {
  var didUpdateListViewController: ((CollectiblesListViewController) -> Void)? { get set }
  var didUpdateIsConnecting: ((Bool) -> Void)? { get set }
  
  func viewDidLoad()
}

final class CollectiblesViewModelImplementation: CollectiblesViewModel, CollectiblesModuleOutput {
  
  // MARK: - CollectiblesModuleOutput
  
  var didSelectNFT: ((NFT) -> Void)?
  
  var didUpdateListViewController: ((CollectiblesListViewController) -> Void)?
  
  // MARK: - CollectiblesViewModel
  
  var didUpdateIsConnecting: ((Bool) -> Void)?
  
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
      await collectiblesController.start()
      await collectiblesController.updateConnectingState()
    }
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
    listModule.output.didSelectNFT = { [weak self] nft in
      self?.didSelectNFT?(nft)
    }
    didUpdateListViewController?(listModule.view)
  }
}

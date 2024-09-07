import UIKit
import TKCore
import TKUIKit
import TKLocalize
import KeeperCore
import TonSwift

protocol CollectiblesModuleOutput: AnyObject {

}

protocol CollectiblesModuleInput: AnyObject {

}

protocol CollectiblesViewModel: AnyObject {
  var didUpdateIsLoading: ((Bool) -> Void)? { get set }
  var didUpdateIsEmpty: ((_ isEmpty: Bool) -> Void)? { get set }

  func viewDidLoad()
}

final class CollectiblesViewModelImplementation: CollectiblesViewModel, CollectiblesModuleOutput, CollectiblesModuleInput {
  
  // MARK: - CollectiblesModuleOutput
  
  // MARK: - CollectiblesModuleInput

  // MARK: - CollectiblesViewModel
  
  var didUpdateIsLoading: ((Bool) -> Void)?
  var didUpdateIsEmpty: ((Bool) -> Void)?

  func viewDidLoad() {
    
    backgroundUpdateStore.addObserver(self) { observer, event in
      observer.didGetBackgroundUpdateStoreEvent(event)
    }
    
    walletStateLoader.addObserver(self) { observer, event in
      observer.didGetWalletStateLoaderEvent(event)
    }
    
    walletNFTStore.addObserver(self) { observer, event in
      observer.didGetWalletNFTStoreEvent(event)
    }
    
    update()
  }
  
  // MARK: Dependencies
  
  private let wallet: Wallet
  private let walletNFTStore: WalletNFTStore
  private let backgroundUpdateStore: BackgroundUpdateStoreV3
  private let walletStateLoader: WalletStateLoader
  
  init(wallet: Wallet,
       walletNFTStore: WalletNFTStore,
       backgroundUpdateStore: BackgroundUpdateStoreV3,
       walletStateLoader: WalletStateLoader) {
    self.wallet = wallet
    self.walletNFTStore = walletNFTStore
    self.backgroundUpdateStore = backgroundUpdateStore
    self.walletStateLoader = walletStateLoader
  }
}

private extension CollectiblesViewModelImplementation {
  func didGetBackgroundUpdateStoreEvent(_ event: BackgroundUpdateStoreV3.Event) {
    switch event {
    case .didUpdateState:
      DispatchQueue.main.async {
        self.update()
      }
    }
  }
  
  func didGetWalletStateLoaderEvent(_ event: WalletStateLoader.Event) {
    switch event {
    case .didStartLoadNFT(let wallet):
      guard wallet == self.wallet else { return }
      DispatchQueue.main.async {
        self.update()
      }
    case .didEndLoadNFT(let wallet):
      guard wallet == self.wallet else { return }
      DispatchQueue.main.async {
        self.update()
      }
    default: break
    }
  }
  
  func didGetWalletNFTStoreEvent(_ event: WalletNFTStore.Event) {
    switch event {
    case .didUpdateNFTs(let wallet):
      guard wallet == self.wallet else { return }
      DispatchQueue.main.async {
        self.update()
      }
    }
  }
  
  func update() {
    let isLoading = {
      let updateState = backgroundUpdateStore.getState()
      let isBackgroundUpdate: Bool
      switch updateState {
      case .connected:
        isBackgroundUpdate = false
      default:
        isBackgroundUpdate = true
      }
      
      let isLoadingNft = walletStateLoader.getState().nftLoadTasks[wallet] != nil
      
      return isLoadingNft || isBackgroundUpdate
    }()
    
    let isEmpty = (walletNFTStore.getState()[wallet] ?? []).isEmpty
    let listHidden = isEmpty && !isLoading
    
    didUpdateIsLoading?(isLoading)
    didUpdateIsEmpty?(listHidden)
  }
}

import UIKit
import TKCore
import TKUIKit
import TKLocalize
import KeeperCore
import TonSwift

protocol CollectiblesModuleOutput: AnyObject {
  var didTapCollectiblesDetails: (() -> Void)? { get set }
}

protocol CollectiblesModuleInput: AnyObject {

}

protocol CollectiblesViewModel: AnyObject {
  var didUpdateIsLoading: ((Bool) -> Void)? { get set }
  var didUpdateIsEmpty: ((_ isEmpty: Bool) -> Void)? { get set }
  var didUpdateNavigationRightButtonVisibility: ((_ isHidden: Bool) -> Void)? { get set }
  var didTapDetailsButton: (() -> Void)? { get set }

  func viewDidLoad()
}

final class CollectiblesViewModelImplementation: CollectiblesViewModel, CollectiblesModuleOutput, CollectiblesModuleInput {
  
  // MARK: - CollectiblesModuleOutput

  var didTapCollectiblesDetails: (() -> Void)?

  // MARK: - CollectiblesModuleInput

  // MARK: - CollectiblesViewModel
  
  var didUpdateIsLoading: ((Bool) -> Void)?
  var didUpdateIsEmpty: ((Bool) -> Void)?
  var didUpdateNavigationRightButtonVisibility: ((_ isVisible: Bool) -> Void)?
  var didTapDetailsButton: (() -> Void)?

  func viewDidLoad() {
    configureBindings()
    update()
  }

  private func configureBindings() {
    backgroundUpdateStore.addObserver(self) { observer, event in
      observer.didGetBackgroundUpdateStoreEvent(event)
    }

    walletStateLoader.addObserver(self) { observer, event in
      observer.didGetWalletStateLoaderEvent(event)
    }

    walletNFTManagedStore.addObserver(self) { observer, event in
      observer.didGetWalletNFTStoreEvent(event)
    }
    didTapDetailsButton = { [weak self] in
      self?.didTapCollectiblesDetails?()
    }
  }

  // MARK: Dependencies
  
  private let wallet: Wallet
  private let walletNFTManagedStore: WalletNFTsManagedStore
  private let backgroundUpdateStore: BackgroundUpdateStore
  private let walletStateLoader: WalletStateLoader
  
  init(wallet: Wallet,
       walletNFTManagedStore: WalletNFTsManagedStore,
       backgroundUpdateStore: BackgroundUpdateStore,
       walletStateLoader: WalletStateLoader) {
    self.wallet = wallet
    self.walletNFTManagedStore = walletNFTManagedStore
    self.backgroundUpdateStore = backgroundUpdateStore
    self.walletStateLoader = walletStateLoader
  }
}

private extension CollectiblesViewModelImplementation {
  func didGetBackgroundUpdateStoreEvent(_ event: BackgroundUpdateStore.Event) {
    switch event {
    case .didUpdateConnectionState(_, let wallet):
      guard wallet == self.wallet else { return }
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
  
  func didGetWalletNFTStoreEvent(_ event: WalletNFTsManagedStore.Event) {
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
      let updateState = backgroundUpdateStore.getState()[wallet] ?? .connecting
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
    
    let isEmpty = walletNFTManagedStore.getState().isEmpty
    let listHidden = isEmpty && !isLoading
    
    didUpdateIsLoading?(isLoading)
    didUpdateNavigationRightButtonVisibility?(listHidden)
    didUpdateIsEmpty?(listHidden)
  }
}

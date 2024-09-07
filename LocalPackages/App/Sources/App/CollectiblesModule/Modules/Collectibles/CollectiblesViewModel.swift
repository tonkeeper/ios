import UIKit
import TKCore
import TKUIKit
import TKLocalize
import KeeperCore
import TonSwift

protocol CollectiblesModuleOutput: AnyObject {
  var didChangeWallet: ((Wallet) -> Void)? { get set }
  var didSelectNFT: ((_ wallet: Wallet, _ nft: NFT) -> Void)? { get set }
}
protocol CollectiblesModuleInput: AnyObject {
  func setListModuleOutput(_ output: CollectiblesListModuleOutput)
}

protocol CollectiblesViewModel: AnyObject {
  var didUpdateState: ((_ state: HistoryViewController.State, _ animated: Bool) -> Void)? { get set }
  var didUpdateEmptyModel: ((TKEmptyViewController.Model) -> Void)? { get set }
  var didUpdateIsConnecting: ((Bool) -> Void)? { get set }
  
  func viewDidLoad()
}

final class CollectiblesViewModelImplementation: CollectiblesViewModel, CollectiblesModuleOutput, CollectiblesModuleInput {
  
  // MARK: - CollectiblesModuleOutput
  
  var didChangeWallet: ((Wallet) -> Void)?
  var didSelectNFT: ((_ wallet: Wallet, _ nft: NFT) -> Void)?
  
  // MARK: - CollectiblesModuleInput
  
  func setListModuleOutput(_ output: any CollectiblesListModuleOutput) {
    output.didUpdate = { [weak self] hasEvents in
      let state: CollectiblesViewController.State = hasEvents ? .list : .empty
      DispatchQueue.main.async {
        self?.didUpdateState?(state, false)
      }
    }
    
    output.didSelectNFT = { [weak self] nft, wallet in
      DispatchQueue.main.async {
        self?.didSelectNFT?(wallet, nft)
      }
    }
  }

  // MARK: - CollectiblesViewModel
  
  var didUpdateState: ((_ state: HistoryViewController.State, _ animated: Bool) -> Void)?
  var didUpdateEmptyModel: ((TKEmptyViewController.Model) -> Void)?
  var didUpdateIsConnecting: ((Bool) -> Void)?
  
  func viewDidLoad() {
    walletsStore.addObserver(self) { observer, event in
      switch event {
      case .didChangeActiveWallet(let wallet):
        DispatchQueue.main.async {
          observer.didChangeActiveWallet(wallet: wallet)
        }
      default: break
      }
    }
    
    backgroundUpdateStore.addObserver(self, notifyOnAdded: false) { observer, newState, oldState in
      DispatchQueue.main.async {
        observer.didUpdateBackgroundUpdateState(newState: newState)
      }
    }
    
    guard let wallet = try? walletsStore.getActiveWallet() else { return }
    didChangeWallet?(wallet)
    setupEmpty(wallet: wallet)
    didUpdateState?(.list, false)
    
    let state = backgroundUpdateStore.getState()
    didUpdateBackgroundUpdateState(newState: state)
  }
  
  // MARK: Dependencies
  
  private let walletsStore: WalletsStoreV3
  private let backgroundUpdateStore: BackgroundUpdateStore
  
  init(walletsStore: WalletsStoreV3,
       backgroundUpdateStore: BackgroundUpdateStore) {
    self.walletsStore = walletsStore
    self.backgroundUpdateStore = backgroundUpdateStore
  }
}

private extension CollectiblesViewModelImplementation {
  func setupEmpty(wallet: Wallet) {
    let model = TKEmptyViewController.Model(
      title: TKLocales.Purchases.empty_placeholder,
      caption: nil,
      buttons: []
    )
    didUpdateEmptyModel?(model)
  }
  
  func didChangeActiveWallet(wallet: Wallet) {
    didChangeWallet?(wallet)
  }
  
  func didUpdateBackgroundUpdateState(newState: BackgroundUpdateStore.State) {
    switch newState {
    case .connecting:
      didUpdateIsConnecting?(true)
    case .connected:
      didUpdateIsConnecting?(false)
    case .disconnected:
      didUpdateIsConnecting?(true)
    case .noConnection:
      didUpdateIsConnecting?(true)
    }
  }

}

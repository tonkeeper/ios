import UIKit
import TKUIKit
import TKLocalize
import KeeperCore

protocol HistoryV2ModuleOutput: AnyObject {
  var didTapBuy: ((Wallet) -> Void)? { get set }
  var didTapReceive: ((Wallet) -> Void)? { get set }
  var didChangeWallet: ((Wallet) -> Void)? { get set }
  var didSelectEvent: ((AccountEventDetailsEvent) -> Void)? { get set }
  var didSelectNFT: ((NFT) -> Void)? { get set }
}
protocol HistoryV2ModuleInput: AnyObject {
  func setListModuleOutput(_ output: HistoryV2ListModuleOutput)
}
protocol HistoryV2ViewModel: AnyObject {
  var didUpdateState: ((HistoryV2ViewController.State) -> Void)? { get set }
  var didUpdateEmptyModel: ((TKEmptyViewController.Model) -> Void)? { get set }
  var didUpdateIsConnecting: ((Bool) -> Void)? { get set }
  
  func viewDidLoad()
}

final class HistoryV2ViewModelImplementation: HistoryV2ViewModel, HistoryV2ModuleOutput, HistoryV2ModuleInput {
  var didTapBuy: ((Wallet) -> Void)?
  var didTapReceive: ((Wallet) -> Void)?
  var didChangeWallet: ((Wallet) -> Void)?
  var didSelectEvent: ((AccountEventDetailsEvent) -> Void)?
  var didSelectNFT: ((NFT) -> Void)?
  
  func setListModuleOutput(_ output: HistoryV2ListModuleOutput) {
    output.didUpdate = { [weak self] hasEvents in
      let state: HistoryV2ViewController.State = hasEvents ? .list : .empty
      DispatchQueue.main.async {
        self?.didUpdateState?(state)
      }
    }
    
    output.didSelectEvent = { [weak self] event in
      self?.didSelectEvent?(event)
    }
  }
  
  var didUpdateState: ((HistoryV2ViewController.State) -> Void)?
  var didUpdateEmptyModel: ((TKEmptyViewController.Model) -> Void)?
  var didUpdateIsConnecting: ((Bool) -> Void)?
  
  private let walletsStore: WalletsStore
  private let backgroundUpdateStore: BackgroundUpdateStore
  
  init(walletsStore: WalletsStore,
       backgroundUpdateStore: BackgroundUpdateStore) {
    self.walletsStore = walletsStore
    self.backgroundUpdateStore = backgroundUpdateStore
  }
  
  func viewDidLoad() {
    walletsStore.addObserver(self, notifyOnAdded: false) { observer, newState, oldState in
      DispatchQueue.main.async {
        observer.didUpdateWalletsState(newState: newState, oldState: oldState)
      }
    }
    
    backgroundUpdateStore.addObserver(self, notifyOnAdded: false) { observer, newState, oldState in
      DispatchQueue.main.async {
        observer.didUpdateBackgroundUpdateState(newState: newState)
      }
    }
    
    let wallet = walletsStore.getState().activeWallet
    didChangeWallet?(wallet)
    setupEmpty(wallet: wallet)
    didUpdateState?(.list)
    
    let state = backgroundUpdateStore.getState()
    didUpdateBackgroundUpdateState(newState: state)
  }
}

private extension HistoryV2ViewModelImplementation {
  func setupEmpty(wallet: Wallet) {
    let model = TKEmptyViewController.Model(
      title: TKLocales.History.Placeholder.title,
      caption: TKLocales.History.Placeholder.subtitle,
      buttons: [
        TKEmptyViewController.Model.Button(
          title: TKLocales.History.Placeholder.Buttons.buy,
          action: { [weak self] in
            guard let self else { return }
            self.didTapBuy?(self.walletsStore.getState().activeWallet)
          }
        ),
        TKEmptyViewController.Model.Button(
          title: TKLocales.History.Placeholder.Buttons.receive,
          action: { [weak self] in
            guard let self else { return }
            self.didTapReceive?(self.walletsStore.getState().activeWallet)
          }
        )
      ]
    )
    didUpdateEmptyModel?(model)
  }
  
  func didUpdateWalletsState(newState: WalletsState, oldState: WalletsState) {
    guard newState.activeWallet != oldState.activeWallet else { return }
    didChangeWallet?(newState.activeWallet)
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

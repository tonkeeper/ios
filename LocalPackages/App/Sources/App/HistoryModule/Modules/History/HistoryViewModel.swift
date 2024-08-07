import UIKit
import TKUIKit
import TKLocalize
import KeeperCore
import TonSwift

protocol HistoryModuleOutput: AnyObject {
  var didTapBuy: ((Wallet) -> Void)? { get set }
  var didTapReceive: ((Wallet) -> Void)? { get set }
  var didChangeWallet: ((Wallet) -> Void)? { get set }
  var didSelectEvent: ((AccountEventDetailsEvent) -> Void)? { get set }
  var didSelectNFT: ((_ wallet: Wallet, _ address: Address) -> Void)? { get set }
  var didSelectEncryptedComment: ((_ wallet: Wallet, _ payload: EncryptedCommentPayload) -> Void)? { get set }
}
protocol HistoryModuleInput: AnyObject {
  func setListModuleOutput(_ output: HistoryListModuleOutput)
}
protocol HistoryViewModel: AnyObject {
  var didUpdateState: ((HistoryViewController.State) -> Void)? { get set }
  var didUpdateEmptyModel: ((TKEmptyViewController.Model) -> Void)? { get set }
  var didUpdateIsConnecting: ((Bool) -> Void)? { get set }
  
  func viewDidLoad()
}

final class HistoryV2ViewModelImplementation: HistoryViewModel, HistoryModuleOutput, HistoryModuleInput {
  var didTapBuy: ((Wallet) -> Void)?
  var didTapReceive: ((Wallet) -> Void)?
  var didChangeWallet: ((Wallet) -> Void)?
  var didSelectEvent: ((AccountEventDetailsEvent) -> Void)?
  var didSelectNFT: ((_ wallet: Wallet, _ address: Address) -> Void)?
  var didSelectEncryptedComment: ((_ wallet: Wallet, _ payload: EncryptedCommentPayload) -> Void)?
  
  func setListModuleOutput(_ output: HistoryListModuleOutput) {
    output.didUpdate = { [weak self] hasEvents in
      let state: HistoryViewController.State = hasEvents ? .list : .empty
      DispatchQueue.main.async {
        self?.didUpdateState?(state)
      }
    }
    
    output.didSelectEvent = { [weak self] event in
      self?.didSelectEvent?(event)
    }
    
    output.didSelectNFT = { [weak self] wallet, address in
      self?.didSelectNFT?(wallet, address)
    }
    
    output.didSelectEncryptedComment = { [weak self] wallet, payload in
      self?.didSelectEncryptedComment?(wallet, payload)
    }
  }
  
  var didUpdateState: ((HistoryViewController.State) -> Void)?
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

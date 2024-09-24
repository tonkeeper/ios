import UIKit
import TKUIKit
import TKLocalize
import KeeperCore
import TonSwift

protocol HistoryModuleOutput: AnyObject {
  var didTapBuy: ((Wallet) -> Void)? { get set }
  var didTapReceive: ((Wallet) -> Void)? { get set }
}

protocol HistoryModuleInput: AnyObject {
  func setHasEvents(_ hasEvents: Bool)
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
  
  func setHasEvents(_ hasEvents: Bool) {
    self.state = hasEvents ? .list : .empty
  }
  
  var didUpdateState: ((HistoryViewController.State) -> Void)?
  var didUpdateEmptyModel: ((TKEmptyViewController.Model) -> Void)?
  var didUpdateIsConnecting: ((Bool) -> Void)?
  
  private var state: ContentListEmptyViewController.State = .list {
    didSet {
      didUpdateState?(state)
    }
  }
  
  private let wallet: Wallet
  private let backgroundUpdateStore: BackgroundUpdateStore
  
  init(wallet: Wallet,
       backgroundUpdateStore: BackgroundUpdateStore) {
    self.wallet = wallet
    self.backgroundUpdateStore = backgroundUpdateStore
  }
  
  func viewDidLoad() {
    setupEmpty(wallet: wallet)
    didUpdateState?(state)
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
            self.didTapBuy?(wallet)
          }
        ),
        TKEmptyViewController.Model.Button(
          title: TKLocales.History.Placeholder.Buttons.receive,
          action: { [weak self] in
            guard let self else { return }
            self.didTapReceive?(wallet)
          }
        )
      ]
    )
    didUpdateEmptyModel?(model)
  }
}

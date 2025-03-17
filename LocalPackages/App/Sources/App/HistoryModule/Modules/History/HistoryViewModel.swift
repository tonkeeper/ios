import UIKit
import TKUIKit
import TKLocalize
import KeeperCore
import TonSwift

protocol HistoryModuleOutput: AnyObject {}

protocol HistoryModuleInput: AnyObject {
  func setHistoryListState(_ state: HistoryList.State)
}

protocol HistoryViewModel: AnyObject {
  var didUpdateIsConnecting: ((Bool) -> Void)? { get set }
  
  var didUpdateTabs: (([TKTabsView.Item]) -> Void)? { get set }
  var didUpdateTabViewIsHidden: ((Bool) -> Void)? { get set }
  
  func viewDidLoad()
}

final class HistoryV2ViewModelImplementation: HistoryViewModel, HistoryModuleOutput, HistoryModuleInput {
  var didSelectSpam: (() -> Void)?
  var didSelectAll: (() -> Void)?
  
  var didChangeWallet: ((Wallet) -> Void)?

  var didUpdateIsConnecting: ((Bool) -> Void)?
  var didUpdateTabs: (([TKTabsView.Item]) -> Void)?
  var didUpdateTabViewIsHidden: ((Bool) -> Void)?
  
  private let wallet: Wallet
  private let backgroundUpdate: BackgroundUpdate
  private let historyListModuleInput: HistoryListModuleInput
  
  init(wallet: Wallet,
       backgroundUpdate: BackgroundUpdate,
       historyListModuleInput: HistoryListModuleInput) {
    self.wallet = wallet
    self.backgroundUpdate = backgroundUpdate
    self.historyListModuleInput = historyListModuleInput
  }
  
  func setHistoryListState(_ state: HistoryList.State) {
    switch state {
    case .loading:
      didUpdateTabViewIsHidden?(true)
    case .content, .empty:
      didUpdateTabViewIsHidden?(false)
    }
  }
  
  var didSelectFilter: ((HistoryList.Filter) -> Void)?

  func viewDidLoad() {
    setupTabs()

    backgroundUpdate.addStateObserver(self) { observer, wallet, state in
      DispatchQueue.main.async {
        guard wallet == observer.wallet else { return }
        observer.didUpdateIsConnecting?(observer.isConnecting(state))
      }
    }
    didUpdateIsConnecting?(isConnecting(backgroundUpdate.getState(wallet: wallet)))
  }
  
  private func isConnecting(_ backgroundUpdateState: BackgroundUpdateConnectionState) -> Bool {
    switch backgroundUpdateState {
    case .connected: return false
    default: return true
    }
  }
  
  private func setupTabs() {
    let tabs = [
      TKTabsView.Item(
        title: TKLocales.History.Tab.all,
        isSelectable: false,
        action: { [weak self] in
          self?.historyListModuleInput.filter = .all
        }),
      TKTabsView.Item(
        title: TKLocales.History.Tab.spam,
        isSelectable: true,
        action: { [weak self] in
          self?.historyListModuleInput.filter = .spam
        })
    ]
    didUpdateTabs?(tabs)
    didUpdateTabViewIsHidden?(true)
  }
}

import UIKit
import TKUIKit
import KeeperCore
import TKCore

protocol HistoryModuleOutput: AnyObject {
  
}

protocol HistoryViewModel: AnyObject {
  var didUpdateListViewController: ((UIViewController) -> Void)? { get set }
  var didUpdateEmptyViewController: ((UIViewController) -> Void)? { get set }
  
  func viewDidLoad()
}

final class HistoryViewModelImplementation: HistoryViewModel, HistoryModuleOutput {
  
  // MARK: - HistoryModuleOutput
  
  // MARK: - HistoryViewModel
  
  var didUpdateListViewController: ((UIViewController) -> Void)?
  var didUpdateEmptyViewController: ((UIViewController) -> Void)?
  
  func viewDidLoad() {
    historyController.didUpdateWallet = { [weak self] in
      self?.setupChildren()
    }
    setupChildren()
  }
  
  // MARK: - Child
  
  private var listInput: HistoryListModuleInput?
  
  // MARK: - Dependencies
  
  private let historyController: HistoryController
  private let listModuleProvider: (Wallet) -> MVVMModule<HistoryListViewController, HistoryListViewModel, HistoryListModuleInput>
  private let emptyModuleProvider: (Wallet) -> MVVMModule<HistoryEmptyViewController, HistoryEmptyViewModel, Void>
  
  // MARK: - Init
  
  init(historyController: HistoryController,
       listModuleProvider: @escaping (Wallet) -> MVVMModule<HistoryListViewController, HistoryListViewModel, HistoryListModuleInput>,
       emptyModuleProvider: @escaping (Wallet) -> MVVMModule<HistoryEmptyViewController, HistoryEmptyViewModel, Void>) {
    self.historyController = historyController
    self.listModuleProvider = listModuleProvider
    self.emptyModuleProvider = emptyModuleProvider
  }
}

private extension HistoryViewModelImplementation {
  func setupChildren() {
    let listModule = listModuleProvider(historyController.wallet)
    listInput = listModule.input
    didUpdateListViewController?(listModule.view)
    
    let emptyModule = emptyModuleProvider(historyController.wallet)
    didUpdateEmptyViewController?(emptyModule.view)
  }
}

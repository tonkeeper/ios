import UIKit
import TKUIKit
import KeeperCore
import TKCore

protocol HistoryModuleOutput: AnyObject {
  var didTapReceive: (() -> Void)? { get set }
  var didSelectEvent: ((AccountEventDetailsEvent) -> Void)? { get set }
  var didSelectNFT: ((NFT) -> Void)? { get set }
}

protocol HistoryViewModel: AnyObject {
  var didUpdateListViewController: ((HistoryListViewController) -> Void)? { get set }
  var didUpdateEmptyViewController: ((UIViewController) -> Void)? { get set }
  var didUpdateIsEmpty: ((Bool) -> Void)? { get set }
  var didUpdateIsConnecting: ((Bool) -> Void)? { get set }
  
  func viewDidLoad()
}

final class HistoryViewModelImplementation: HistoryViewModel, HistoryModuleOutput {
  
  // MARK: - HistoryModuleOutput
  
  var didTapReceive: (() -> Void)?
  var didSelectEvent: ((AccountEventDetailsEvent) -> Void)?
  var didSelectNFT: ((NFT) -> Void)?
  
  // MARK: - HistoryViewModel
  
  var didUpdateListViewController: ((HistoryListViewController) -> Void)?
  var didUpdateEmptyViewController: ((UIViewController) -> Void)?
  var didUpdateIsEmpty: ((Bool) -> Void)?
  var didUpdateIsConnecting: ((Bool) -> Void)?
  
  func viewDidLoad() {
    historyController.didUpdateWallet = { [weak self] in
      guard let self else { return }
      Task { @MainActor in
        self.setupChildren()
      }
    }
    historyController.didUpdateIsConnecting = { [weak self] isConnecting in
      guard let self = self else { return }
      Task { @MainActor in
        self.didUpdateIsConnecting?(isConnecting)
      }
    }
    
    historyController.updateConnectingState()
    
    setupChildren()
  }
  
  // MARK: - Child
  
  private var listInput: HistoryListModuleInput?
  
  // MARK: - Dependencies
  
  private let historyController: HistoryController
  private let listModuleProvider: (Wallet) -> MVVMModule<HistoryListViewController, HistoryListModuleOutput, HistoryListModuleInput>
  private let emptyModuleProvider: (Wallet) -> MVVMModule<HistoryEmptyViewController, HistoryEmptyModuleOutput, Void>
  
  // MARK: - Init
  
  init(historyController: HistoryController,
       listModuleProvider: @escaping (Wallet) -> MVVMModule<HistoryListViewController, HistoryListModuleOutput, HistoryListModuleInput>,
       emptyModuleProvider: @escaping (Wallet) -> MVVMModule<HistoryEmptyViewController, HistoryEmptyModuleOutput, Void>) {
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
    
    listModule.output.noEvents = { [weak self] in
      self?.didUpdateIsEmpty?(true)
    }
    
    listModule.output.hasEvents = { [weak self] in
      self?.didUpdateIsEmpty?(false)
    }
    
    listModule.output.didSelectEvent = { [weak self] event in
      self?.didSelectEvent?(event)
    }
    
    listModule.output.didSelectNFT = { [weak self] nft in
      self?.didSelectNFT?(nft)
    }
    
    let emptyModule = emptyModuleProvider(historyController.wallet)
    
    emptyModule.output.didTapReceive = { [weak self] in
      self?.didTapReceive?()
    }
    
    didUpdateEmptyViewController?(emptyModule.view)
  }
}

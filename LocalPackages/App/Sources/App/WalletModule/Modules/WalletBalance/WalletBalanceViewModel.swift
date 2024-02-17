import Foundation
import TKUIKit
import KeeperCore

protocol WalletBalanceModuleOutput: AnyObject {
  var didSelectTon: (() -> Void)? { get set }
  var didSelectJetton: ((JettonInfo) -> Void)? { get set }
  
  var didTapReceive: (() -> Void)? { get set }
  
  var didTapBackup: (() -> Void)? { get set }
}

protocol WalletBalanceViewModel: AnyObject {
  var didUpdateHeader: ((WalletBalanceHeaderView.Model) -> Void)? { get set }
  var didUpdateBalanceItems: (([WalletBalanceBalanceItemCell.Model]) -> Void)? { get set }
  var didUpdateFinishSetupItems: (([AnyHashable]) -> Void)? { get set }
  var didTapCopy: ((String?) -> Void)? { get set }
  
  func viewDidLoad()
  func didTapBalanceItem(at index: Int)
  func didTapFinishSetupItem(at index: Int)
}

final class WalletBalanceViewModelImplementation: WalletBalanceViewModel, WalletBalanceModuleOutput {
  
  // MARK: - WalletBalanceModuleOutput
  
  var didSelectTon: (() -> Void)?
  var didSelectJetton: ((JettonInfo) -> Void)?
  
  var didTapReceive: (() -> Void)?
  
  var didTapBackup: (() -> Void)?
  
  // MARK: - WalletBalanceViewModel
  
  var didUpdateHeader: ((WalletBalanceHeaderView.Model) -> Void)?
  var didUpdateBalanceItems: (([WalletBalanceBalanceItemCell.Model]) -> Void)?
  var didUpdateFinishSetupItems: (([AnyHashable]) -> Void)?
  var didTapCopy: ((String?) -> Void)?
  
  func viewDidLoad() {
    walletBalanceController.didUpdateBalance = { [weak self] balanceModel in
      self?.updateBalance(balanceModel: balanceModel)
    }
    
    walletBalanceController.didUpdateFinishSetup = { [weak self] model in
      self?.updateFinishSetup(model: model)
    }
    
    walletBalanceController.loadBalance()
  }
  
  func didTapBalanceItem(at index: Int) {
    balanceItems[index].selectionHandler?()
  }
  
  func didTapFinishSetupItem(at index: Int) {
    switch finishSetupItems[index] {
    case let item as WalletBalanceBalanceItemCell.Model:
      item.selectionHandler?()
    default: break
    }
  }
  
  // MARK: - State
  
  private var balanceModel: WalletBalanceModel?
  
  private var balanceItems = [WalletBalanceBalanceItemCell.Model]() {
    didSet {
      didUpdateBalanceItems?(balanceItems)
    }
  }
  
  private var finishSetupItems = [AnyHashable]() {
    didSet {
      didUpdateFinishSetupItems?(finishSetupItems)
    }
  }
  
  // MARK: - Mapper
  
  private let listItemMapper = WalletBalanceListItemMapper()
  
  // MARK: - Init
  
  private let walletBalanceController: WalletBalanceController
  
  init(walletBalanceController: WalletBalanceController) {
    self.walletBalanceController = walletBalanceController
  }
}

private extension WalletBalanceViewModelImplementation {
  func updateBalance(balanceModel: WalletBalanceModel) {
    let headerModel = createHeaderModel(balanceModel: balanceModel)
    let balanceItems = balanceModel.items.map { item in
      listItemMapper.mapBalanceItems(item) { [weak self] in
        switch item.token {
        case .ton:
          self?.didSelectTon?()
        case .jetton(let jettonInfo):
          self?.didSelectJetton?(jettonInfo)
        }
      }
    }
    
    Task { @MainActor in
      self.balanceModel = balanceModel
      didUpdateHeader?(headerModel)
      self.balanceItems = balanceItems
    }
  }
  
  func createHeaderModel(balanceModel: WalletBalanceModel) -> WalletBalanceHeaderView.Model {
    let balanceViewModel = WalletBalanceHeaderBalanceView.Model(
      balance: balanceModel.total,
      address: walletBalanceController.address,
      addressAction: { [weak self] in
        self?.didTapCopy?(self?.walletBalanceController.fullAddress)
      }
    )
    
    return WalletBalanceHeaderView.Model(
      balanceViewModel: balanceViewModel,
      buttonsViewModel: createButtonsViewModel()
    )
  }

  func createButtonsViewModel() -> WalletBalanceHeaderButtonsView.Model {
    WalletBalanceHeaderButtonsView.Model(buttons: [
      WalletBalanceHeaderButtonsView.Model.Button(
        configuration: TKUIIconButton.Model(image: .TKUIKit.Icons.Size28.arrowUpOutline, title: "Send"),
        action: {}
      ),
      WalletBalanceHeaderButtonsView.Model.Button(
        configuration: TKUIIconButton.Model(image: .TKUIKit.Icons.Size28.arrowDownOutline, title: "Receive"),
        action: { [weak self] in
          self?.didTapReceive?()
        }
      ),
      WalletBalanceHeaderButtonsView.Model.Button(
        configuration: TKUIIconButton.Model(image: .TKUIKit.Icons.Size28.qrViewFinderThin, title: "Scan"),
        action: {}
      ),
      WalletBalanceHeaderButtonsView.Model.Button(
        configuration: TKUIIconButton.Model(image: .TKUIKit.Icons.Size28.swapHorizontalOutline, title: "Swap"),
        action: {}
      ),
      WalletBalanceHeaderButtonsView.Model.Button(
        configuration: TKUIIconButton.Model(image: .TKUIKit.Icons.Size28.usd, title: "Buy or Sell"),
        action: {}
      ),
      WalletBalanceHeaderButtonsView.Model.Button(
        configuration: TKUIIconButton.Model(image: .TKUIKit.Icons.Size28.stakingOutline, title: "Stake"),
        action: {}
      )
    ])
  }
  
  func updateFinishSetup(model: WalletBalanceSetupModel) {
    finishSetupItems = listItemMapper.mapFinishSetup(
      model: model,
      backupHandler: { [weak self] in
        self?.didTapBackup?()
      }
    )
  }
}

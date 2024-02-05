import Foundation
import TKUIKit
import KeeperCore

protocol WalletBalanceModuleOutput: AnyObject {
  
}

protocol WalletBalanceViewModel: AnyObject {
  var didUpdateHeader: ((WalletBalanceHeaderView.Model) -> Void)? { get set }
  var didUpdateBalanceItems: (([WalletBalanceBalanceItemCell.Model]) -> Void)? { get set }
  
  func viewDidLoad()
  func didTapBalanceItem(at index: Int)
}

final class WalletBalanceViewModelImplementation: WalletBalanceViewModel, WalletBalanceModuleOutput {
  
  // MARK: - WalletBalanceModuleOutput
  
  // MARK: - WalletBalanceViewModel
  
  var didUpdateHeader: ((WalletBalanceHeaderView.Model) -> Void)?
  var didUpdateBalanceItems: (([WalletBalanceBalanceItemCell.Model]) -> Void)?
  
  func viewDidLoad() {
    walletBalanceController.didUpdateBalance = { [weak self] balanceModel in
      guard let self = self else { return }
      self.updateBalance(balanceModel: balanceModel)
    }
    walletBalanceController.loadBalance()
  }
  
  func didTapBalanceItem(at index: Int) {
    balanceItems[index].selectionHandler?()
  }
  
  // MARK: - State
  
  private var balanceModel: WalletBalanceModel?
  
  private var balanceItems = [WalletBalanceBalanceItemCell.Model]() {
    didSet {
      didUpdateBalanceItems?(balanceItems)
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
      listItemMapper.mapBalanceItems(item) {
        print("Did tap balance item")
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
      addressAction: {}
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
        action: {}
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
}

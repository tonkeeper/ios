import Foundation
import TKUIKit
import KeeperCore

protocol WalletBalanceModuleOutput: AnyObject {
  var didSelectTon: (() -> Void)? { get set }
  var didSelectJetton: ((JettonInfo) -> Void)? { get set }
  
  var didTapReceive: (() -> Void)? { get set }
  
  var didTapBackup: (() -> Void)? { get set }
  
  var didRequireConfirmation: (() async -> Bool)? { get set }
}

protocol WalletBalanceViewModel: AnyObject {
  var didUpdateHeader: ((WalletBalanceHeaderView.Model) -> Void)? { get set }
  var didUpdateBalanceItems: (([WalletBalanceBalanceItemCell.Model]) -> Void)? { get set }
  var didUpdateFinishSetupItems: (([AnyHashable], WalletBalanceCollectionController.SectionHeaderView.Model) -> Void)? { get set }
  var didTapCopy: ((String?) -> Void)? { get set }
  
  func viewDidLoad()
  func didTapBalanceItem(at index: Int)
  func didTapFinishSetupItem(at index: Int)
  func isHighlightableItem(section: WalletBalanceSection, index: Int) -> Bool
  func didTapSectionHeaderButton(section: WalletBalanceSection)
}

final class WalletBalanceViewModelImplementation: WalletBalanceViewModel, WalletBalanceModuleOutput {
  
  // MARK: - WalletBalanceModuleOutput
  
  var didSelectTon: (() -> Void)?
  var didSelectJetton: ((JettonInfo) -> Void)?
  
  var didTapReceive: (() -> Void)?
  
  var didTapBackup: (() -> Void)?
  
  var didRequireConfirmation: (() async -> Bool)?
  
  // MARK: - WalletBalanceViewModel
  
  var didUpdateHeader: ((WalletBalanceHeaderView.Model) -> Void)?
  var didUpdateBalanceItems: (([WalletBalanceBalanceItemCell.Model]) -> Void)?
  var didUpdateFinishSetupItems: (([AnyHashable], WalletBalanceCollectionController.SectionHeaderView.Model) -> Void)?
  var didTapCopy: ((String?) -> Void)?
  
  func viewDidLoad() {
    walletBalanceController.didUpdateBalance = { [weak self] in
      self?.updateBalance()
    }
    
    walletBalanceController.didUpdateFinishSetup = { [weak self] model in
      self?.updateFinishSetup(model: model)
    }
    
    walletBalanceController.didUpdateBackgroundUpdateState = { [weak self] state in
      self?.updateBalance()
    }
    
    walletBalanceController.loadBalance()
  }
  
  func didTapBalanceItem(at index: Int) {
    balanceItems[index].selectionHandler?()
  }
  
  func didTapFinishSetupItem(at index: Int) {
    switch finishSetupItems[index] {
    case let item as WalletBalanceSetupPlainItemCell.Model:
      item.selectionHandler?()
    default: break
    }
  }
  
  func isHighlightableItem(section: WalletBalanceSection, index: Int) -> Bool {
    switch section {
    case .balanceItems:
      return true
    case .finishSetup:
      switch finishSetupItems[index] {
      case let item as WalletBalanceSetupPlainItemCell.Model:
        return item.isHighlightable
      case let item as WalletBalanceSetupSwitchItemCell.Model:
        return item.isHighlightable
      default: return false
      }
    }
  }
  
  func didTapSectionHeaderButton(section: WalletBalanceSection) {
    switch section {
    case .balanceItems:
      break
    case .finishSetup:
      walletBalanceController.finishSetup()
    }
  }
  
  // MARK: - State
  
  private var balanceModel: WalletBalanceModel?
  
  private var balanceItems = [WalletBalanceBalanceItemCell.Model]() {
    didSet {
      didUpdateBalanceItems?(balanceItems)
    }
  }
  
  private var finishSetupItems = [AnyHashable]()
  
  // MARK: - Mapper
  
  private let listItemMapper = WalletBalanceListItemMapper()
  
  // MARK: - Init
  
  private let walletBalanceController: WalletBalanceController
  
  init(walletBalanceController: WalletBalanceController) {
    self.walletBalanceController = walletBalanceController
  }
}

private extension WalletBalanceViewModelImplementation {
  func updateBalance() {
    Task {
      async let balanceModelTask =  walletBalanceController.walletBalanceModel
      async let backgroundUpdateStateTask = walletBalanceController.backgroundUpdateState
      
      let balanceModel = await balanceModelTask
      let backgroundUpdateState = await backgroundUpdateStateTask
      
      let headerModel = createHeaderModel(
        balanceModel: balanceModel,
        backgroundUpdateState: backgroundUpdateState
      )
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
  }
  
  func createHeaderModel(balanceModel: WalletBalanceModel,
                         backgroundUpdateState: BackgroundUpdateStore.State) -> WalletBalanceHeaderView.Model {
    
    let connectionStatusModel: ConnectionStatusView.Model?
    switch backgroundUpdateState {
    case .connecting:
      connectionStatusModel = ConnectionStatusView.Model(
        title: "Updating",
        titleColor: .Text.secondary,
        isLoading: true
      )
    case .connected:
      connectionStatusModel = nil
    case .disconnected:
      connectionStatusModel = ConnectionStatusView.Model(
        title: "Updating",
        titleColor: .Text.secondary,
        isLoading: true
      )
    case .noConnection:
      connectionStatusModel = ConnectionStatusView.Model(
        title: "No Internet connection",
        titleColor: .Accent.orange,
        isLoading: false
      )
    }
    
    let balanceViewModel = WalletBalanceHeaderBalanceView.Model(
      balance: balanceModel.total,
      address: walletBalanceController.address,
      addressAction: {
        [weak self] in
        self?.didTapCopy?(self?.walletBalanceController.fullAddress)
      },
      connectionStatusModel: connectionStatusModel
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
    let headerModel = listItemMapper.mapFinishSetupSectionHeaderModel(model: model)
    finishSetupItems = listItemMapper.mapFinishSetup(
      model: model,
      biometryAuthentificator: BiometryAuthentificator(),
      backupHandler: { [weak self] in
        self?.didTapBackup?()
      }, biometryHandler: { [weak self] isOn in
        guard let self = self else { return !isOn }
        let didConfirm = await self.didRequireConfirmation?() ?? false
        guard didConfirm else { return !isOn }
        return await Task { @MainActor in
          return self.walletBalanceController.setIsBiometryEnabled(isOn)
        }.value
      }
    )
    didUpdateFinishSetupItems?(finishSetupItems, headerModel)
  }
}

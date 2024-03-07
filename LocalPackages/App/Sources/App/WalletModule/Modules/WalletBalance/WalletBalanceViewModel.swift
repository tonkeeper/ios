import Foundation
import TKUIKit
import KeeperCore

protocol WalletBalanceModuleOutput: AnyObject {
  var didSelectTon: (() -> Void)? { get set }
  var didSelectJetton: ((JettonItem) -> Void)? { get set }
  
  var didTapReceive: (() -> Void)? { get set }
  var didTapSend: (() -> Void)? { get set }
  var didTapScan: (() -> Void)? { get set }
  
  var didTapBackup: (() -> Void)? { get set }
  
  var didRequireConfirmation: (() async -> Bool)? { get set }
}

protocol WalletBalanceViewModel: AnyObject {
  var didUpdateHeader: ((WalletBalanceHeaderView.Model) -> Void)? { get set }
  var didUpdateTonItems: (([WalletBalanceBalanceItemCell.Model]) -> Void)? { get set }
  var didUpdateJettonsItems: (([WalletBalanceBalanceItemCell.Model]) -> Void)? { get set }
  var didUpdateFinishSetupItems: (([AnyHashable], WalletBalanceCollectionController.SectionHeaderView.Model) -> Void)? { get set }
  var didTapCopy: ((String?) -> Void)? { get set }
  
  func viewDidLoad()
  func didTapTonItem(at index: Int)
  func didTapJettonItem(at index: Int)
  func didTapFinishSetupItem(at index: Int)
  func isHighlightableItem(section: WalletBalanceSection, index: Int) -> Bool
  func didTapSectionHeaderButton(section: WalletBalanceSection)
}

final class WalletBalanceViewModelImplementation: WalletBalanceViewModel, WalletBalanceModuleOutput {
  
  // MARK: - WalletBalanceModuleOutput
  
  var didSelectTon: (() -> Void)?
  var didSelectJetton: ((JettonItem) -> Void)?
  
  var didTapReceive: (() -> Void)?
  var didTapSend: (() -> Void)?
  var didTapScan: (() -> Void)?
  
  var didTapBackup: (() -> Void)?
  
  var didRequireConfirmation: (() async -> Bool)?
  
  // MARK: - WalletBalanceViewModel
  
  var didUpdateHeader: ((WalletBalanceHeaderView.Model) -> Void)?
  var didUpdateTonItems: (([TKCollectionViewContainerCell<WalletBalanceBalanceItemCellContentView>.Model]) -> Void)?
  var didUpdateJettonsItems: (([TKCollectionViewContainerCell<WalletBalanceBalanceItemCellContentView>.Model]) -> Void)?
  var didUpdateFinishSetupItems: (([AnyHashable], WalletBalanceCollectionController.SectionHeaderView.Model) -> Void)?
  var didTapCopy: ((String?) -> Void)?
  
  func viewDidLoad() {
    updateHeader()
    updateBalance()
    Task {
      self.backgroundUpdateState = await BackgroundUpdateState(state: walletBalanceController.backgroundUpdateState)
    }
    
    walletBalanceController.didUpdateBalance = { [weak self] in
      self?.didUpdateBalance()
    }
    
    walletBalanceController.didUpdateTotalBalance = { [weak self] in
      self?.didUpdateTotalBalance()
    }
    
    walletBalanceController.didUpdateFinishSetup = { [weak self] model in
      self?.updateFinishSetup(model: model)
    }
    
    walletBalanceController.didUpdateBackgroundUpdateState = { [weak self] state in
      self?.didUpdateBackgroundUpdateState(state: state)
    }
    
    walletBalanceController.loadBalance()
  }
  
  func didTapTonItem(at index: Int) {
    tonItems[index].selectionHandler?()
  }
  
  func didTapJettonItem(at index: Int) {
    jettonsItems[index].selectionHandler?()
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
    case .jettonsItems, .tonItems:
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
    case .finishSetup:
      walletBalanceController.finishSetup()
    default: break
    }
  }
  
  // MARK: - State
    
  private var tonItems = [WalletBalanceBalanceItemCell.Model]() {
    didSet {
      didUpdateTonItems?(tonItems)
    }
  }
  private var jettonsItems = [WalletBalanceBalanceItemCell.Model]() {
    didSet {
      didUpdateJettonsItems?(jettonsItems)
    }
  }
  
  private var backgroundUpdateState: BackgroundUpdateState = .disconnected {
    didSet {
      guard oldValue != backgroundUpdateState else { return }
      Task { @MainActor in
        updateHeader()
      }
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
    let balanceModel = walletBalanceController.walletBalanceModel
    let tonItems = balanceModel.tonItems.map { item in
      listItemMapper.mapBalanceItems(item) { [weak self] in
        switch item.token {
        case .ton:
          self?.didSelectTon?()
        case .jetton(let jettonInfo):
          self?.didSelectJetton?(jettonInfo)
        }
      }
    }
    
    let jettonsItems = balanceModel.jettonsItems.map  { item in
      listItemMapper.mapBalanceItems(item) { [weak self] in
        switch item.token {
        case .ton:
          self?.didSelectTon?()
        case .jetton(let jettonInfo):
          self?.didSelectJetton?(jettonInfo)
        }
      }
    }
    self.tonItems = tonItems
    self.jettonsItems = jettonsItems
  }
  
  func updateHeader() {
    let headerModel = createHeaderModel(
      backgroundUpdateState: backgroundUpdateState
    )
    didUpdateHeader?(headerModel)
  }
  
  func createHeaderModel(backgroundUpdateState: BackgroundUpdateState) -> WalletBalanceHeaderView.Model {
    
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
      balance: walletBalanceController.totalBalanceFormatted,
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
        isEnabled: true,
        action: { [weak self] in
          self?.didTapSend?()
        }
      ),
      WalletBalanceHeaderButtonsView.Model.Button(
        configuration: TKUIIconButton.Model(image: .TKUIKit.Icons.Size28.arrowDownOutline, title: "Receive"),
        action: { [weak self] in
          self?.didTapReceive?()
        }
      ),
      WalletBalanceHeaderButtonsView.Model.Button(
        configuration: TKUIIconButton.Model(image: .TKUIKit.Icons.Size28.qrViewFinderThin, title: "Scan"),
        action: { [weak self] in
          self?.didTapScan?()
        }
      ),
      WalletBalanceHeaderButtonsView.Model.Button(
        configuration: TKUIIconButton.Model(image: .TKUIKit.Icons.Size28.swapHorizontalOutline, title: "Swap"),
        isEnabled: false,
        action: {}
      ),
      WalletBalanceHeaderButtonsView.Model.Button(
        configuration: TKUIIconButton.Model(image: .TKUIKit.Icons.Size28.usd, title: "Buy or Sell"),
        isEnabled: false,
        action: {}
      ),
      WalletBalanceHeaderButtonsView.Model.Button(
        configuration: TKUIIconButton.Model(image: .TKUIKit.Icons.Size28.stakingOutline, title: "Stake"),
        isEnabled: false,
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
  
  func didUpdateTotalBalance() {
    Task { @MainActor in
      self.updateHeader()
    }
  }
  
  func didUpdateBackgroundUpdateState(state: BackgroundUpdateStore.State) {
    Task { @MainActor in
      self.backgroundUpdateState = BackgroundUpdateState(state: state)
    }
  }
  
  func didUpdateBalance() {
    Task { @MainActor in
      self.updateBalance()
    }
  }
}

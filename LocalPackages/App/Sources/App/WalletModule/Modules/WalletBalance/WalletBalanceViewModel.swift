import Foundation
import TKUIKit
import KeeperCore
import UIKit
import TKLocalize

protocol WalletBalanceModuleOutput: AnyObject {
  var didSelectTon: ((Wallet) -> Void)? { get set }
  var didSelectJetton: ((Wallet, JettonItem, Bool) -> Void)? { get set }

  var didTapReceive: (() -> Void)? { get set }
  var didTapSend: (() -> Void)? { get set }
  var didTapScan: (() -> Void)? { get set }
  var didTapBuy: ((Wallet) -> Void)? { get set }
  
  var didTapBackup: ((Wallet) -> Void)? { get set }
  var didRequireConfirmation: (() async -> Bool)? { get set }
}

protocol WalletBalanceModuleInput: AnyObject {}

protocol WalletBalanceViewModel: AnyObject {
  var didChangeWallet: (() -> Void)? { get set }
  var didUpdateHeader: ((WalletBalanceHeaderView.Model) -> Void)? { get set }
  var didUpdateTonItems: (([TKUIListItemCell.Configuration]) -> Void)? { get set }
  var didUpdateJettonItems: (([TKUIListItemCell.Configuration]) -> Void)? { get set }
  var didUpdateFinishSetupItems: (([TKUIListItemCell.Configuration]) -> Void)? { get set }
  var didCopy: ((ToastPresenter.Configuration) -> Void)? { get set }

  var finishSetupSectionHeaderModel: TKListTitleView.Model { get }
  
  func viewDidLoad()
  func didTapFinishSetupButton()
}

final class WalletBalanceViewModelImplementation: WalletBalanceViewModel, WalletBalanceModuleOutput, WalletBalanceModuleInput {
  
  // MARK: - WalletBalanceModuleOutput
  
  var didSelectTon: ((Wallet) -> Void)?
  var didSelectJetton: ((Wallet, JettonItem, Bool) -> Void)?
  var didUpdateFinishSetupItems: (([TKUIListItemCell.Configuration]) -> Void)?
  
  var didTapReceive: (() -> Void)?
  var didTapSend: (() -> Void)?
  var didTapScan: (() -> Void)?
  var didTapBuy: ((Wallet) -> Void)?
  
  var didTapBackup: ((Wallet) -> Void)?
  var didRequireConfirmation: (() async -> Bool)?
  
  // MARK: - WalletBalanceViewModel
  
  var didChangeWallet: (() -> Void)?
  var didUpdateHeader: ((WalletBalanceHeaderView.Model) -> Void)?
  var didUpdateTonItems: (([TKUIListItemCell.Configuration]) -> Void)?
  var didUpdateJettonItems: (([TKUIListItemCell.Configuration]) -> Void)?
  var didCopy: ((ToastPresenter.Configuration) -> Void)?
  
  var finishSetupSectionHeaderModel = TKListTitleView.Model(title: "", textStyle: .label1, buttonContent: nil)

  func viewDidLoad() {
    Task {
      walletBalanceController.didChangeWallet = { [weak self] in
        guard let self else { return }
        Task { @MainActor in
          self.didChangeWallet?()
        }
      }
      
      await walletBalanceController.start(didUpdateState: { [weak self] stateModel in
        self?.didUpdateStateModel(stateModel)
      }, didUpdateBalanceState: { [weak self] model in
        self?.didUpdateBalanceStateModel(model)
      }, didUpdateSetupState: { [weak self] model in
        self?.didUpdateSetupState(model)
      })
    }
  }
  
  func didTapFinishSetupButton() {
    Task { await walletBalanceController.finishSetup() }
  }
  
  // MARK: - Mapper
  
  private let listItemMapper = WalletBalanceListItemMapper()
  
  // MARK: - Dependencies
  
  private let walletBalanceController: WalletBalanceController
  
  // MARK: - Init
  
  init(walletBalanceController: WalletBalanceController) {
    self.walletBalanceController = walletBalanceController
  }
}

private extension WalletBalanceViewModelImplementation {
  func didUpdateStateModel(_ model: WalletBalanceController.StateModel) {
    let headerModel = createHeaderModel(model)
    Task { @MainActor in
      didUpdateHeader?(headerModel)
    }
  }
  
  func didUpdateBalanceStateModel(_ model: WalletBalanceItemsModel) {
    let tonItems = model.tonItems.map { tonItem in
      listItemMapper.mapBalanceItem(tonItem) { [weak self] in
        guard let wallet = self?.walletBalanceController.wallet else { return }
        switch tonItem.token {
        case .ton:
          self?.didSelectTon?(wallet)
        case .jetton(let jettonInfo):
          self?.didSelectJetton?(wallet, jettonInfo, false)
        }
      }
    }
    
    let jettonsItems = model.jettonsItems.map { jettonItem in
      listItemMapper.mapBalanceItem(jettonItem) { [weak self] in
        guard let wallet = self?.walletBalanceController.wallet else { return }
        switch jettonItem.token {
        case .ton:
          self?.didSelectTon?(wallet)
        case .jetton(let jettonInfo):
          self?.didSelectJetton?(wallet, jettonInfo, jettonItem.hasPrice)
        }
      }
    }
    
    Task { @MainActor in
      didUpdateTonItems?(tonItems)
      didUpdateJettonItems?(jettonsItems)
    }
  }
  
  func didUpdateSetupState(_ model: WalletBalanceSetupModel?) {
    guard let model = model else {
      Task { @MainActor in
        didUpdateFinishSetupItems?([])
      }
      return
    }
    
    let finishSetupItems = listItemMapper.mapFinishSetup(
      model: model,
      biometryAuthentificator: BiometryAuthentificator(),
      backupHandler: { [weak self] in
        guard let wallet = self?.walletBalanceController.wallet else { return }
        self?.didTapBackup?(wallet)
      },
      biometryHandler: { [weak self] isOn in
        guard let self = self else { return !isOn }
        let didConfirm = await self.didRequireConfirmation?() ?? false
        guard didConfirm else { return !isOn }
        let isOnResult = await walletBalanceController.setIsBiometryEnabled(isOn)
        return await Task { @MainActor in
          return isOnResult
        }.value
      }
    )
    Task { @MainActor in
      var buttonContent: TKButton.Configuration.Content?
      if model.isFinishSetupAvailable {
        buttonContent = TKButton.Configuration.Content(title: .plainString(TKLocales.Actions.done))
      }
      finishSetupSectionHeaderModel = TKListTitleView.Model(title: TKLocales.FinishSetup.title, textStyle: .label1, buttonContent: buttonContent)
      didUpdateFinishSetupItems?(finishSetupItems)
    }
  }
  
  func createHeaderModel(_ model: WalletBalanceController.StateModel) -> WalletBalanceHeaderView.Model {
    var stateDate: String?
    if let modelStateDate = model.stateDate {
      stateDate = TKLocales.ConnectionStatus.updated_at(modelStateDate)
    }

    let balanceModel = WalletBalanceHeaderBalanceView.Model(
      balance: model.totalBalance,
      addressButtonConfiguration: TKButton.Configuration(
        content: TKButton.Configuration.Content(title: .plainString(model.shortAddress ?? "")),
        textStyle: .body2,
        textColor: .Text.secondary,
        contentAlpha: [.normal: 1, .highlighted: 0.48],
        action: { [weak self] in
          self?.didTapCopy(
            walletAddress: model.fullAddress, 
            walletType: model.walletType
          )
        }
      ),
      connectionStatusModel: createConnectionStatusModel(backgroundUpdateState: model.backgroundUpdateState),
      tagConfiguration: createTagConfiguration(walletType: model.walletType),
      stateDate: stateDate
    )
    
    return WalletBalanceHeaderView.Model(
      balanceModel: balanceModel,
      buttonsViewModel: createHeaderButtonsModel(walletType: model.walletType)
    )
  }
  
  func createTagConfiguration(walletType: WalletModel.WalletType) -> TKUITagView.Configuration? {
    switch walletType {
    case .regular:
      return nil
    case .watchOnly:
      return TKUITagView.Configuration(
        text: TKLocales.WalletTags.watch_only,
        textColor: .Accent.orange,
        backgroundColor: UIColor.init(
          hex: "332d24"
        )
      )
    case .external:
      return TKUITagView.Configuration(
        text: "SIGNER",
        textColor: .Accent.purple,
        backgroundColor: .Accent.purple.withAlphaComponent(0.16)
      )
    }
  }

  func didTapCopy(walletAddress: String?,
                  walletType: WalletModel.WalletType) {
    UINotificationFeedbackGenerator().notificationOccurred(.warning)
    UIPasteboard.general.string = walletAddress
    
    let backgroundColor: UIColor
    let foregroundColor: UIColor
    switch walletType {
    case .regular:
      backgroundColor = .Background.contentTint
      foregroundColor = .Text.primary
    case .watchOnly:
      backgroundColor = .Accent.orange
      foregroundColor = .Text.primary
    case .external:
      backgroundColor = .Accent.purple
      foregroundColor = .Text.primary
    }
    let configuration = ToastPresenter.Configuration(
      title: TKLocales.Actions.copied,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      dismissRule: .default
    )
    didCopy?(configuration)
  }

  func createConnectionStatusModel(backgroundUpdateState: KeeperCore.BackgroundUpdateState) -> ConnectionStatusView.Model? {
    switch backgroundUpdateState {
    case .connecting:
      return ConnectionStatusView.Model(
        title: TKLocales.ConnectionStatus.updating,
        titleColor: .Text.secondary,
        isLoading: true
      )
    case .connected:
      return nil
    case .disconnected:
      return ConnectionStatusView.Model(
        title: TKLocales.ConnectionStatus.updating,
        titleColor: .Text.secondary,
        isLoading: true
      )
    case .noConnection:
      return ConnectionStatusView.Model(
        title: TKLocales.ConnectionStatus.no_internet,
        titleColor: .Accent.orange,
        isLoading: false
      )
    }
  }
  
  func createHeaderButtonsModel(walletType: WalletModel.WalletType) -> WalletBalanceHeaderButtonsView.Model {
    let isSendEnable: Bool
    let isReceiveEnable: Bool
    let isScanEnable: Bool
    let isSwapEnable: Bool
    let isBuyEnable: Bool
    let isStakeEnable: Bool
    
    switch walletType {
    case .regular:
      isSendEnable = true
      isReceiveEnable = true
      isScanEnable = true
      isSwapEnable = false
      isBuyEnable = true
      isStakeEnable = false
    case .watchOnly:
      isSendEnable = false
      isReceiveEnable = true
      isScanEnable = false
      isSwapEnable = false
      isBuyEnable = true
      isStakeEnable = false
    case .external:
      isSendEnable = true
      isReceiveEnable = true
      isScanEnable = true
      isSwapEnable = false
      isBuyEnable = true
      isStakeEnable = false
    }
    
    return WalletBalanceHeaderButtonsView.Model(
      sendButton: WalletBalanceHeaderButtonsView.Model.Button(
        title: TKLocales.WalletButtons.send,
        icon: .TKUIKit.Icons.Size28.arrowUpOutline,
        isEnabled: isSendEnable,
        action: { [weak self] in self?.didTapSend?() }
      ),
      recieveButton: WalletBalanceHeaderButtonsView.Model.Button(
        title: TKLocales.WalletButtons.receive,
        icon: .TKUIKit.Icons.Size28.arrowDownOutline,
        isEnabled: isReceiveEnable,
        action: { [weak self] in self?.didTapReceive?() }
      ),
      scanButton: WalletBalanceHeaderButtonsView.Model.Button(
        title: TKLocales.WalletButtons.scan,
        icon: .TKUIKit.Icons.Size28.qrViewFinderThin,
        isEnabled: isScanEnable,
        action: { [weak self] in self?.didTapScan?() }
      ),
      swapButton: WalletBalanceHeaderButtonsView.Model.Button(
        title: TKLocales.WalletButtons.swap,
        icon: .TKUIKit.Icons.Size28.swapHorizontalOutline,
        isEnabled: isSwapEnable,
        action: {}
      ),
      buyButton: WalletBalanceHeaderButtonsView.Model.Button(
        title: TKLocales.WalletButtons.buy,
        icon: .TKUIKit.Icons.Size28.usd,
        isEnabled: isBuyEnable,
        action: { [weak self] in
          guard let wallet = self?.walletBalanceController.wallet else { return }
          self?.didTapBuy?(wallet) }
      ),
      stakeButton: WalletBalanceHeaderButtonsView.Model.Button(
        title: TKLocales.WalletButtons.stake,
        icon: .TKUIKit.Icons.Size28.stakingOutline,
        isEnabled: isStakeEnable,
        action: {}
      )
    )
  }
}

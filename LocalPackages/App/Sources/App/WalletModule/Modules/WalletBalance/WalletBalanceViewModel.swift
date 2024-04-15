import Foundation
import TKUIKit
import KeeperCore
import UIKit

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
  var didUpdateTonItems: (([TKUIListItemCell.Configuration]) -> Void)? { get set }
  var didUpdateJettonItems: (([TKUIListItemCell.Configuration]) -> Void)? { get set }
  var didUpdateFinishSetupItems: (([TKUIListItemCell.Configuration]) -> Void)? { get set }
  var didCopy: ((ToastPresenter.Configuration) -> Void)? { get set }

  var finishSetupSectionHeaderModel: TKListTitleView.Model { get }
  
  func viewDidLoad()
  func didTapFinishSetupButton()
}

final class WalletBalanceViewModelImplementation: WalletBalanceViewModel, WalletBalanceModuleOutput {
  
  // MARK: - WalletBalanceModuleOutput
  
  var didSelectTon: (() -> Void)?
  var didSelectJetton: ((JettonItem) -> Void)?
  var didUpdateFinishSetupItems: (([TKUIListItemCell.Configuration]) -> Void)?
  
  var didTapReceive: (() -> Void)?
  var didTapSend: (() -> Void)?
  var didTapScan: (() -> Void)?
  
  var didTapBackup: (() -> Void)?
  var didRequireConfirmation: (() async -> Bool)?
  
  // MARK: - WalletBalanceViewModel
  
  var didUpdateHeader: ((WalletBalanceHeaderView.Model) -> Void)?
  var didUpdateTonItems: (([TKUIListItemCell.Configuration]) -> Void)?
  var didUpdateJettonItems: (([TKUIListItemCell.Configuration]) -> Void)?
  var didCopy: ((ToastPresenter.Configuration) -> Void)?
  
  var finishSetupSectionHeaderModel = TKListTitleView.Model(title: "", buttonContent: nil)

  func viewDidLoad() {
    Task {
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
        switch tonItem.token {
        case .ton:
          self?.didSelectTon?()
        case .jetton(let jettonInfo):
          self?.didSelectJetton?(jettonInfo)
        }
      }
    }
    
    let jettonsItems = model.jettonsItems.map { jettonItem in
      listItemMapper.mapBalanceItem(jettonItem) { [weak self] in
        switch jettonItem.token {
        case .ton:
          self?.didSelectTon?()
        case .jetton(let jettonInfo):
          self?.didSelectJetton?(jettonInfo)
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
        self?.didTapBackup?()
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
        buttonContent = TKButton.Configuration.Content(title: .plainString("Done"))
      }
      finishSetupSectionHeaderModel = TKListTitleView.Model(title: "Finish setting up", buttonContent: buttonContent)
      didUpdateFinishSetupItems?(finishSetupItems)
    }
  }
  
  func createHeaderModel(_ model: WalletBalanceController.StateModel) -> WalletBalanceHeaderView.Model {
    var stateDate: String?
    if let modelStateDate = model.stateDate {
      stateDate = "Updated \(modelStateDate)"
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
    case .watchOnly(let tag):
      return TKUITagView.Configuration(text: tag, textColor: .Accent.orange, backgroundColor: UIColor.init(hex: "332d24"))
    }
  }

  func didTapCopy(walletAddress: String?,
                  walletType: WalletModel.WalletType) {
    UINotificationFeedbackGenerator().notificationOccurred(.warning)
    UIPasteboard.general.string = walletAddress
    
    let backgroundColor: UIColor
    switch walletType {
    case .regular:
      backgroundColor = .Background.contentTint
    case .watchOnly:
      backgroundColor = .Accent.orange
    }
    let configuration = ToastPresenter.Configuration(
      title: "Copied.",
      backgroundColor: backgroundColor,
      foregroundColor: .Text.primary,
      dismissRule: .default
    )
    didCopy?(configuration)
  }

  func createConnectionStatusModel(backgroundUpdateState: KeeperCore.BackgroundUpdateState) -> ConnectionStatusView.Model? {
    switch backgroundUpdateState {
    case .connecting:
      return ConnectionStatusView.Model(
        title: "Updating",
        titleColor: .Text.secondary,
        isLoading: true
      )
    case .connected:
      return nil
    case .disconnected:
      return ConnectionStatusView.Model(
        title: "Updating",
        titleColor: .Text.secondary,
        isLoading: true
      )
    case .noConnection:
      return ConnectionStatusView.Model(
        title: "No Internet connection",
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
      isBuyEnable = false
      isStakeEnable = false
    case .watchOnly:
      isSendEnable = false
      isReceiveEnable = true
      isScanEnable = false
      isSwapEnable = false
      isBuyEnable = false
      isStakeEnable = false
    }
    
    return WalletBalanceHeaderButtonsView.Model(
      sendButton: WalletBalanceHeaderButtonsView.Model.Button(
        title: "Send",
        icon: .TKUIKit.Icons.Size28.arrowUpOutline,
        isEnabled: isSendEnable,
        action: { [weak self] in self?.didTapSend?() }
      ),
      recieveButton: WalletBalanceHeaderButtonsView.Model.Button(
        title: "Receive",
        icon: .TKUIKit.Icons.Size28.arrowDownOutline,
        isEnabled: isReceiveEnable,
        action: { [weak self] in self?.didTapReceive?() }
      ),
      scanButton: WalletBalanceHeaderButtonsView.Model.Button(
        title: "Scan",
        icon: .TKUIKit.Icons.Size28.qrViewFinderThin,
        isEnabled: isScanEnable,
        action: { [weak self] in self?.didTapScan?() }
      ),
      swapButton: WalletBalanceHeaderButtonsView.Model.Button(
        title: "Swap",
        icon: .TKUIKit.Icons.Size28.swapHorizontalOutline,
        isEnabled: isSwapEnable,
        action: {}
      ),
      buyButton: WalletBalanceHeaderButtonsView.Model.Button(
        title: "Buy TON",
        icon: .TKUIKit.Icons.Size28.usd,
        isEnabled: isBuyEnable,
        action: {}
      ),
      stakeButton: WalletBalanceHeaderButtonsView.Model.Button(
        title: "Stake",
        icon: .TKUIKit.Icons.Size28.stakingOutline,
        isEnabled: isStakeEnable,
        action: {}
      )
    )
  }
}

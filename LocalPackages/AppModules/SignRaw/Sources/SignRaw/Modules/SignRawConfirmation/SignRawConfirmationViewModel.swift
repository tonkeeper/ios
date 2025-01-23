import UIKit
import TKUIKit
import TKLocalize
import KeeperCore
import WalletExtensions

@MainActor
public protocol SignRawConfirmationModuleOutput: AnyObject {
  var didRequireSign: ((TransferData, Wallet) async throws -> SignedTransactions?)? { get set }
  var didConfirm: (() -> Void)? { get set }
  var didRequestShowInfoPopup: ((_ title: String, _ caption: String) -> Void)? { get set }
  var didRequireShowInsufficientPopup: ((_ wallet: Wallet, _ model: SignRawConfirmationModel.ProvisionModel) -> Void)? { get set }
}

@MainActor
public protocol SignRawConfirmationModuleInput: AnyObject {
  func cancel()
}

@MainActor
public protocol SignRawConfirmationViewModel: AnyObject {
  var didUpdateHeader: ((TKUIKit.TKPullCardHeaderItem) -> Void)? { get set }
  var didUpdateConfiguration: ((TKPopUp.Configuration) -> Void)? { get set }
  
  func viewDidLoad()
}

@MainActor
public final class SignRawConfirmationViewModelImplementation: SignRawConfirmationViewModel, SignRawConfirmationModuleOutput, SignRawConfirmationModuleInput {

  // MARK: - SignRawConfirmationModuleOutput
  
  public var didRequireSign: ((TransferData, Wallet) async throws -> SignedTransactions?)?
  public var didConfirm: (() -> Void)?
  public var didRequestShowInfoPopup: ((_ title: String, _ caption: String) -> Void)?
  public var didRequireShowInsufficientPopup: ((_ wallet: Wallet, _ model: SignRawConfirmationModel.ProvisionModel) -> Void)?


  // MARK: - SignRawConfirmationModuleInput
  
  public func cancel() {
    signRawController.cancel()
  }
  
  // MARK: - SignRawConfirmationViewModel
  
  public var didUpdateHeader: ((TKPullCardHeaderItem) -> Void)?
  public var didUpdateConfiguration: ((TKPopUp.Configuration) -> Void)?
  
  public func viewDidLoad() {
    signRawController.signHandler = { [weak self] transferData, wallet in
      try await self?.didRequireSign?(transferData, wallet)
    }
    
    didUpdateHeader?(createHeaderItem())
    updateConfiguration()
    emulate()
  }
  
  // MARK: - State
  
  private struct State {
    enum EmulationState {
      case emulating
      case success(model: SignRawConfirmationModel, transferType: TransferType)
      case fail
      
      var transferType: TransferType {
        switch self {
        case .emulating:
          return .default
        case .success(_, let transferType):
          return transferType
        case .fail:
          return .default
        }
      }
    }
    
    enum ConfirmationState {
      case idle
      case process
      case success
      case failed
    }
    
    var emulationState: EmulationState = .emulating
    var confirmationState: ConfirmationState = .idle
  }
  
  private var state = State() {
    didSet {
      updateConfiguration()
    }
  }

  private let wallet: Wallet
  private let signRawController: SignRawController
  private let signRawConfirmationMapper: SignRawConfirmationMapper
  
  init(wallet: Wallet,
       signRawController: SignRawController,
       signRawConfirmationMapper: SignRawConfirmationMapper) {
    self.wallet = wallet
    self.signRawController = signRawController
    self.signRawConfirmationMapper = signRawConfirmationMapper
  }
  
  private func emulate() {
    Task { [weak self] in
      guard let self else { return }
      do {
        let emulationResult = try await signRawController.emulate()
        let model = signRawConfirmationMapper.mapEmulationResult(emulation: emulationResult, wallet: wallet)
        if let provisionModel = model.provisionModel, isInsufficientBalanceFlow(model: provisionModel) {
          self.didRequireShowInsufficientPopup?(self.wallet, provisionModel)
          state.emulationState = .fail
          return
        }
        state.emulationState = .success(model: model, transferType: emulationResult.transferType)
      } catch {
        state.emulationState = .fail
      }
    }
  }

  private func isInsufficientBalanceFlow(model: SignRawConfirmationModel.ProvisionModel) -> Bool {
    var isInsufficientFlow = false
    let (token, availableBalance) = model.token
    switch token {
    case .ton:
      isInsufficientFlow = model.requiredAmount > model.tonBalance
    case .jetton(let info):
      let isFeeEnough = model.fee <= model.tonBalance
      isInsufficientFlow = !(isFeeEnough && model.requiredAmount <= availableBalance)
    }
    return isInsufficientFlow
  }

  private func updateConfiguration() {
    var items = [TKPopUp.Item]()
    if let loaderItem = createLoaderItem() {
      items.append(loaderItem)
    }
    if let contentItem = createContentItem() {
      items.append(contentItem)
    }
    items.append(createProcessItem())
    
    let configuration = TKPopUp.Configuration(
      items: items
    )
    didUpdateConfiguration?(configuration)
  }
  
  private func createLoaderItem() -> TKPopUp.Item? {
    guard case .emulating = state.emulationState else { return nil }
    return TKPopUp.Component.GroupComponent(
      padding: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16),
      items: [
        TKPopUp.Component.Loader(
          size: .medium,
          style: .primary
        )
      ]
    )
  }
  
  private func createProcessItem() -> TKPopUp.Item {
    var items = [TKPopUp.Item]()
    items.append(createSliderItem())
    items.append(createRiskItem())

    let processItem = TKPopUp.Component.Process(
      items: items,
      state: {
        switch state.confirmationState {
        case .idle:
          return .idle
        case .process:
          return .process
        case .success:
          return .success
        case .failed:
          return .failed
        }
      }(),
      successTitle: TKLocales.Result.success,
      errorTitle: TKLocales.Result.failure
    )
    
    return processItem
  }
  
  private func createSliderItem() -> TKPopUp.Item {
    let isEnable: Bool
    switch state.emulationState {
    case .emulating:
      isEnable = false
    case .success:
      isEnable = true
    case .fail:
      isEnable = true
    }
    
    let sliderItem = TKPopUp.Component.Slider(
      title: TKLocales.ConfirmSend.confirm,
      isEnable: isEnable,
      didConfirm: { [weak self] in
        self?.confirmTransaction()
      }
    )
    
    return TKPopUp.Component.GroupComponent(
      padding: UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16),
      items: [
        sliderItem
      ]
    )
  }
  
  private func createRiskItem() -> TKPopUp.Item {
    let failedItem: () -> TKPopUp.Item = {
      return TKPopUp.Component.LabelComponent(
        text: TKLocales.State.failed.withTextStyle(
          .body2,
          color: .Text.secondary,
          alignment: .center,
          lineBreakMode: .byTruncatingTail
        ),
        numberOfLines: 1
      )
    }
    
    let loadingItem: () -> TKPopUp.Item = {
      return TKPopUp.Component.LabelComponent(
        text: TKLocales.Toast.loading.withTextStyle(
          .body2,
          color: .Text.secondary,
          alignment: .center,
          lineBreakMode: .byTruncatingTail
        ),
        numberOfLines: 1
      )
    }

    switch state.emulationState {
    case .emulating:
      return loadingItem()
    case .success(let model, _):
      guard let risk = model.risk else { return failedItem() }
      let signRawRiskItem = SignRawRiskView.Model(
        bottomSpace: 0,
        title: risk.title,
        isRisk: risk.isRisk,
        action: { [weak self] in
          guard let self, let risk = model.risk else {
            return
          }
          self.didRequestShowInfoPopup?(risk.title, risk.caption)
        }
      )
      return signRawRiskItem
    case .fail:
      return failedItem()
    }
  }
  
  private func createContentItem() -> TKPopUp.Item? {
    switch state.emulationState {
    case .emulating:
      return nil
    case .success(let model, _):
      return TKPopUp.Component.GroupComponent(
        padding: UIEdgeInsets(top: 0, left: 16, bottom: 16, right: 16),
        items: [SignRawContentView.Configuration(
          actionsConfiguration: model.contentModel
        )]
      )
    case .fail:
      return TKPopUp.Component.LabelComponent(
        text: "Emulation failed".withTextStyle(
          .label1,
          color: .Text.primary,
          alignment: .center,
          lineBreakMode: .byTruncatingTail
        ),
        numberOfLines: 1
      )
    }
  }

  private func createHeaderItem() -> TKPullCardHeaderItem {
    let walletString = "\(TKLocales.ConfirmSend.wallet): ".withTextStyle(
      .body2,
      color: .Text.secondary,
      alignment: .left,
      lineBreakMode: .byWordWrapping
    )
    let walletNameString = wallet.iconWithName(
      attributes: TKTextStyle.body2.getAttributes(
        color: .Text.secondary,
        alignment: .left,
        lineBreakMode: .byTruncatingTail
      ),
      iconColor: .Icon.primary,
      iconSide: 16
    )
    let subtitle = NSMutableAttributedString(attributedString: walletString)
    subtitle.append(walletNameString)
    
    return TKPullCardHeaderItem(
      title: .title(
        title: TKLocales.ConfirmSend.TokenTransfer.title,
        subtitle: subtitle
      )
    )
  }

  private func confirmTransaction() {
    Task {
      state.confirmationState = .process
      do {
        try await signRawController.sendTransaction(transactionType: state.emulationState.transferType)
        state.confirmationState = .success
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        didConfirm?()
      } catch {
        state.confirmationState = .failed
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        state.confirmationState = .idle
      }
    }
  }
}

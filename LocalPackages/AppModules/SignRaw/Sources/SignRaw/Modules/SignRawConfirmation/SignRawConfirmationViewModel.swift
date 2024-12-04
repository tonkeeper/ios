import UIKit
import TKUIKit
import TKLocalize
import KeeperCore
import WalletExtensions

@MainActor
protocol SignRawConfirmationModuleOutput: AnyObject {
  var didRequireSign: ((TransferData, Wallet) async throws -> String?)? { get set }
  var didConfirm: (() -> Void)? { get set }
}

@MainActor
protocol SignRawConfirmationModuleInput: AnyObject {
  func cancel()
}

@MainActor
protocol SignRawConfirmationViewModel: AnyObject {
  var didUpdateHeader: ((TKUIKit.TKPullCardHeaderItem) -> Void)? { get set }
  var didUpdateConfiguration: ((TKPopUp.Configuration) -> Void)? { get set }
  
  func viewDidLoad()
}

@MainActor
final class SignRawConfirmationViewModelImplementation: SignRawConfirmationViewModel, SignRawConfirmationModuleOutput, SignRawConfirmationModuleInput {
  
  // MARK: - SignRawConfirmationModuleOutput
  
  var didRequireSign: ((TransferData, Wallet) async throws -> String?)?
  var didConfirm: (() -> Void)?
  
  // MARK: - SignRawConfirmationModuleInput
  
  func cancel() {
    
  }
  
  // MARK: - SignRawConfirmationViewModel
  
  var didUpdateHeader: ((TKPullCardHeaderItem) -> Void)?
  var didUpdateConfiguration: ((TKPopUp.Configuration) -> Void)?
  
  func viewDidLoad() {
    signRawController.signHandler = { [weak self] transferData, wallet in
      try await self?.didRequireSign?(transferData, wallet)
    }
    
    didUpdateHeader?(createHeaderItem())
    let configuration = createConfiguration()
    didUpdateConfiguration?(configuration)
    emulate()
  }
  
  // MARK: - State
  
  private enum State {
    case emulating
    case idle
    case confirmation(confirmationState: ConfirmationState)
  }
  
  private enum ConfirmationState {
    case process
    case success
    case failed
  }
  
  private var state: State = .emulating {
    didSet {
      didUpdateConfiguration?(createConfiguration())
    }
  }
  
  private var emulationResult: SignRawEmulationResult? {
    didSet {
      guard let emulationResult else {
        model = nil
        return
      }
      model = signRawConfirmationMapper.mapEmulationResult(emulationResult: emulationResult, wallet: wallet)
    }
  }
  private var model: SignRawConfirmationModel? {
    didSet {
      didUpdateConfiguration?(createConfiguration())
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
    Task {
      emulationResult = try await signRawController.emulate()
      self.state = .idle
    }
  }
  
  private func createConfiguration() -> TKPopUp.Configuration {
    switch state {
    case .emulating:
      createEmulatingConfiguration()
    case .idle:
      createIdleConfiguration()
    case .confirmation(let confirmationState):
      createConfirmationConfiguration(
        confirmationState: confirmationState
      )
    }
  }
  
  private func createEmulatingConfiguration() -> TKPopUp.Configuration {
    let items: [TKPopUp.Item] = [
      createEmulationLoaderItem(),
      createProcessItem()
    ]
    let configuration = TKPopUp.Configuration(
      items: items
    )
    
    return configuration
  }
  
  private func createIdleConfiguration() -> TKPopUp.Configuration {
    var items = [TKPopUp.Item]()
    if let contentItem = createContentItem() {
      items.append(contentItem)
    }
    items.append(createProcessItem())
    let configuration = TKPopUp.Configuration(
      items: items
    )
    
    return configuration
  }
  
  private func createConfirmationConfiguration(confirmationState: ConfirmationState) -> TKPopUp.Configuration {
    var items = [TKPopUp.Item]()
    if let contentItem = createContentItem() {
      items.append(contentItem)
    }
    items.append(createProcessItem())
    let configuration = TKPopUp.Configuration(
      items: items
    )
    
    return configuration
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
  
  private func createEmulationLoaderItem() -> TKPopUp.Item {
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
    if let riskItem = createRiskItem() {
      items.append(riskItem)
    }
    
    let processItem = TKPopUp.Component.Process(
      items: items,
      state: {
        switch state {
        case .emulating:
            return .idle
        case .idle:
            return .idle
        case .confirmation(let confirmationState):
          switch confirmationState {
          case .process:
            return .process
          case .success:
            return .success
          case .failed:
            return .failed
          }
        }
      }(),
      successTitle: TKLocales.Result.success,
      errorTitle: TKLocales.Result.failure
    )
    
    return processItem
  }
  
  private func createSliderItem() -> TKPopUp.Item {
    let isEnable: Bool
    let action: () -> Void
    switch state {
    case .emulating:
      isEnable = false
      action = {}
    case .idle:
      isEnable = true
      action = { [weak self] in
        self?.confirmTransaction()
      }
    case .confirmation:
      isEnable = true
      action = {}
    }
    
    let sliderItem = TKPopUp.Component.Slider(
      title: "Confirm",
      isEnable: isEnable,
      didConfirm: action
    )
    
    return TKPopUp.Component.GroupComponent(
      padding: UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16),
      items: [
        sliderItem
      ]
    )
  }
  
  private func createRiskItem() -> TKPopUp.Item? {
    switch state {
    case .emulating:
      return TKPopUp.Component.LabelComponent(
        text: "Loading".withTextStyle(
          .body2,
          color: .Text.secondary,
          alignment: .center,
          lineBreakMode: .byTruncatingTail
        ),
        numberOfLines: 1
      )
    default:
      guard let risk = model?.risk else { return nil }
      let signRawRiskItem = SignRawRiskView.Model(
        bottomSpace: 0,
        title: risk.title,
        isRisk: risk.isRisk,
        action: {
          
        }
      )
      return signRawRiskItem
    }
  }
  
  private func createContentItem() -> TKPopUp.Item? {
    guard let model else { return nil }
    return TKPopUp.Component.GroupComponent(
      padding: UIEdgeInsets(top: 0, left: 16, bottom: 16, right: 16),
      items: [SignRawContentView.Configuration(
        actionsConfiguration: model.contentModel
      )]
    )
  }
  
  private func confirmTransaction() {
    Task {
      state = .confirmation(confirmationState: .process)
      do {
        try await signRawController.sendTransaction(transactionType: emulationResult?.transactionType ?? .default)
        state = .confirmation(confirmationState: .success)
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        NotificationCenter.default.postTransactionSendNotification(wallet: wallet)
        didConfirm?()
      } catch {
        state = .confirmation(confirmationState: .failed)
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        state = .idle
      }
    }
  }
}

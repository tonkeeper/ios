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
    case idle(emulationResult: SignRawEmulationResult)
    case confirmation(emulationResult: SignRawEmulationResult, confirmationState: ConfirmationState)
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
      let result = try await signRawController.emulate()
      self.state = .idle(emulationResult: result)
    }
  }
  
  private func createConfiguration() -> TKPopUp.Configuration {
    switch state {
    case .emulating:
      createEmulatingConfiguration()
    case .idle(let emulationResult):
      createIdleConfiguration(
        emulationResult: emulationResult
      )
    case .confirmation(let emulationResult, let confirmationState):
      createConfirmationConfiguration(
        emulationResult: emulationResult,
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
  
  private func createIdleConfiguration(emulationResult: SignRawEmulationResult) -> TKPopUp.Configuration {
    let items: [TKPopUp.Item] = [
      createContentItem(emulationResult: emulationResult),
      createProcessItem()
    ]
    let configuration = TKPopUp.Configuration(
      items: items
    )
    
    return configuration
  }
  
  private func createConfirmationConfiguration(emulationResult: SignRawEmulationResult,
                                               confirmationState: ConfirmationState) -> TKPopUp.Configuration {
    let items: [TKPopUp.Item] = [
      createContentItem(emulationResult: emulationResult),
      createProcessItem()
    ]
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
    let processItem: TKPopUp.Item = {
      TKPopUp.Component.Process(
        items: [
          createSliderItem(),
          createRiskItem()
        ],
        state: {
          switch state {
          case .emulating:
              return .idle
          case .idle(_):
              return .idle
          case .confirmation(_, let confirmationState):
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
    }()
    
    return processItem
  }
  
  private func createRiskItem() -> TKPopUp.Item {
    TKPopUp.Component.LabelComponent(
      text: "dsds".withTextStyle(
        .body2,
        color: .gray,
        alignment: .center,
        lineBreakMode: .byWordWrapping
      )
    )
  }
  
  private func createSliderItem() -> TKPopUp.Item {
    let isEnable: Bool
    let action: () -> Void
    switch state {
    case .emulating:
      isEnable = false
      action = {}
    case .idle(let emulationResult):
      isEnable = true
      action = { [weak self] in
        self?.confirmTransaction(emulationResult: emulationResult)
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
  
  private func createContentItem(emulationResult: SignRawEmulationResult) -> TKPopUp.Item {
    let model = signRawConfirmationMapper.mapEmulationResult(
      emulationResult: emulationResult,
      wallet: wallet
    )
    
    return TKPopUp.Component.GroupComponent(
      padding: UIEdgeInsets(top: 0, left: 16, bottom: 16, right: 16),
      items: [SignRawContentView.Configuration(
        actionsConfiguration: model
      )]
    )
  }
  
  private func confirmTransaction(emulationResult: SignRawEmulationResult) {
    Task {
      state = .confirmation(emulationResult: emulationResult, confirmationState: .process)
      do {
        try await signRawController.sendTransaction(emulationResult: emulationResult)
        state = .confirmation(emulationResult: emulationResult, confirmationState: .success)
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        NotificationCenter.default.postTransactionSendNotification(wallet: wallet)
        didConfirm?()
      } catch {
        state = .confirmation(emulationResult: emulationResult, confirmationState: .failed)
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        state = .idle(emulationResult: emulationResult)
      }
    }
  }
}

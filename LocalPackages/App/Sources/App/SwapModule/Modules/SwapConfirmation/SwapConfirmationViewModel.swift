import Foundation
import TKUIKit
import KeeperCore

protocol SwapConfirmationModuleOutput: AnyObject {
  var didFinish: (() -> Void)? { get set }
  var didRequireConfirmation: (() async -> Bool)? { get set }
  var didSendTransaction: (() -> Void)? { get set }
  var didRequireExternalWalletSign: ((URL, Wallet) async throws -> Data?)? { get set }
}

protocol SwapConfirmationViewModel: AnyObject {
  var didUpdateModel: ((SwapConfirmationView.Model) -> Void)? { get set }
  
  func viewDidLoad()
}

final class SwapConfirmationViewModelImplementation: SwapConfirmationViewModel, SwapConfirmationModuleOutput {
  
  // MARK: - SwapConfirmationModuleOutput
  
  var didFinish: (() -> Void)?
  var didRequireConfirmation: (() async -> Bool)?
  var didSendTransaction: (() -> Void)?
  var didRequireExternalWalletSign: ((URL, Wallet) async throws -> Data?)?
  
  // MARK: - SwapConfirmationViewModel
  
  var didUpdateModel: ((SwapConfirmationView.Model) -> Void)?
  
  func viewDidLoad() {
    update()
    setupControllerBindings()
    
    Task {
      await swapConfirmationController.start()
    }
  }
  
  // MARK: - State
  
  private var isEmulationFailed = false
  
  private var isResolving = true {
    didSet {
      guard isResolving != oldValue else { return }
      update()
    }
  }
  
  private var isConfirmEnabled: Bool {
    !isEmulationFailed
  }
  
  // MARK: - Mapper
  
  private let itemMapper = SwapItemMaper()
  
  // MARK: - Dependencies
  
  private let swapConfirmationController: SwapConfirmationController
  private let swapConfirmationItem: SwapConfirmationItem
  
  // MARK: - Init
  
  init(swapConfirmationController: SwapConfirmationController, swapConfirmationItem: SwapConfirmationItem) {
    self.swapConfirmationController = swapConfirmationController
    self.swapConfirmationItem = swapConfirmationItem
  }
  
  deinit {
    print("\(Self.self) deinit")
  }
}

// MARK: - Private

private extension SwapConfirmationViewModelImplementation {
  func setupControllerBindings() {
    swapConfirmationController.didGetError = { [weak self] error in
      self?.handleError(error)
      self?.isResolving = false
    }
    
    swapConfirmationController.didEmulationSuccess = { [weak self] in
      self?.isResolving = false
    }
    
    swapConfirmationController.didGetExternalSign = { [weak self] url in
      guard let self, let didRequireExternalWalletSign else { return Data() }
      return try await didRequireExternalWalletSign(url, swapConfirmationController.wallet)
    }
  }
  
  func update() {
    let model = createModel()
    didUpdateModel?(model)
  }
  
  func createModel() -> SwapConfirmationView.Model {
    SwapConfirmationView.Model (
      title: ModalTitleView.Model(
        title: "Confirm Swap"
      ),
      sendContainer: SwapSendContainerView.Model(
        inputContainerModel: SwapInputContainerView.Model(
          header: itemMapper.mapAmountHeader(
            title: "Send",
            balanceTitle: swapConfirmationItem.convertedFiatAmount
          ),
          tokenButton: itemMapper.mapTokenButton(
            buttonToken: swapConfirmationItem.operationItem.sendToken,
            action: nil
          ),
          textField: SwapInputContainerView.Model.TextField(
            isEnabled: true,
            inputText: swapConfirmationItem.operationItem.sendToken?.inputAmount ?? "0"
          )
        )
      ),
      recieveContainer: SwapRecieveContainerView.Model(
        inputContainerModel: SwapInputContainerView.Model(
          header: itemMapper.mapAmountHeader(
            title: "Recieve",
            balanceTitle: swapConfirmationItem.convertedFiatAmount
          ),
          tokenButton: itemMapper.mapTokenButton(
            buttonToken: swapConfirmationItem.operationItem.recieveToken,
            action: nil
          ),
          textField: SwapInputContainerView.Model.TextField(
            isEnabled: true,
            inputText: swapConfirmationItem.operationItem.recieveToken?.inputAmount ?? "0"
          )
        )
      ),
      infoContainer: itemMapper.mapSwapSimulationInfo(swapConfirmationItem.simulationModel.info),
      cancelButton: SwapConfirmationView.Model.Button(
        title: "Cancel",
        isEnabled: true,
        isActivity: false,
        action: { [weak self] in
          self?.didFinish?()
        }
      ),
      confirmButton: SwapConfirmationView.Model.Button(
        title: "Confirm",
        isEnabled: !isResolving && isConfirmEnabled,
        isActivity: isResolving,
        action: { [weak self] in
          guard let self else { return }
          self.didTapConfirmButton()
        }
      )
    )
  }
  
  func didTapConfirmButton() {
    Task {
      let isConfirmed = await confirmTransaction()
      guard isConfirmed else {
        await MainActor.run { handleError(.failedToConfirm) }
        return
      }
      
      await MainActor.run { isResolving = true }
      
      let isSuccess = await sendTransaction()
      await MainActor.run {
        if isSuccess {
          didSendTransaction?()
        }
        isResolving = false
      }
    }
  }
  
  func confirmTransaction() async -> Bool {
    if swapConfirmationController.isNeedToConfirm() {
      let isConfirmed = await didRequireConfirmation?() ?? false
      return isConfirmed
    }
    return true
  }
  
  func sendTransaction() async -> Bool {
    do {
      try await swapConfirmationController.sendTransaction()
      return true
    } catch {
      return false
    }
  }
  
  func handleError(_ error: SwapConfirmationController.Error) {
    let title: String
    switch error {
    case .failedToEmulate:
      isEmulationFailed = true
      title = "Failed to emulate transaction"
    case .failedToSendTransaction:
      title = "Failed to send transaction"
    case .failedToSign:
      title = "Failed to sign transaction"
    case .failedToConfirm:
      title = "Failed to confirm transaction"
    }
    
    ToastPresenter.showToast(
      configuration: ToastPresenter.Configuration(
        title: title,
        backgroundColor: .Background.contentTint,
        foregroundColor: .Text.primary
      )
    )
  }
}

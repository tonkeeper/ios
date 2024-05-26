import UIKit
import TKUIKit
import TKCore
import KeeperCore
import BigInt
import TonSwift

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
  
  private let swapItemMapper = SwapItemMaper()
  
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
          headerTitle: "Send",
          balanceTitle: swapConfirmationItem.convertedFiatAmount,
          maxButton: nil,
          tokenButton: swapItemMapper.mapTokenButton(
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
          headerTitle: "Recieve",
          balanceTitle: swapConfirmationItem.convertedFiatAmount,
          maxButton: nil,
          tokenButton: swapItemMapper.mapTokenButton(
            buttonToken: swapConfirmationItem.operationItem.recieveToken,
            action: nil
          ),
          textField: SwapInputContainerView.Model.TextField(
            isEnabled: true,
            inputText: swapConfirmationItem.operationItem.recieveToken?.inputAmount ?? "0"
          )
        )
      ),
      infoContainer: swapItemMapper.mapSwapSimulationInfo(swapConfirmationItem.simulationModel.info),
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
    isResolving = true
    Task {
      let isSuccess = await sendTransaction()
      await MainActor.run {
        if isSuccess {
          didSendTransaction?()
        } else  {
          handleError(.failedToSendTransaction)
        }
        isResolving = false
      }
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
    }
    
    ToastPresenter.showToast(
      configuration: ToastPresenter.Configuration(
        title: title,
        backgroundColor: .Background.contentTint,
        foregroundColor: .Text.primary
      )
    )
  }
  
  func sendTransaction() async -> Bool {
    if swapConfirmationController.isNeedToConfirm() {
      let isConfirmed = await didRequireConfirmation?() ?? false
      guard isConfirmed else { return false }
    }
    do {
      try await swapConfirmationController.sendTransaction()
      return true
    } catch {
      return false
    }
  }
}

//extension SwapModel {
//  static let testData = SwapModel(
//    confirmationItem: .testData,
//    transactionItem: .tonToJetton(
//      SwapItem(
//        fromAddress: try! Address.parse("EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c"),
//        toAddress: try! Address.parse("EQCxE6mUtQJKFnGfaROTKOt1lZbDiiX1kCixRv7Nw2Id_sDs"),
//        minAskAmount: BigUInt("6010010000"),
//        offerAmount: BigUInt("1000000000000")
//      )
//    )
//  )
//}
//
//extension SwapConfirmationItem {
//  static let testData = SwapConfirmationItem(
//    convertedFiatAmount: "$ 6,010.01",
//    operationItem: SwapOperationItem(
//      sendToken: .tonStub,
//      recieveToken: .usdtStub
//    ),
//    simulationModel: SwapSimulationModel(
//      offerAmount: SwapSimulationModel.Amount(
//        amount: BigUInt(),
//        converted: "1,000"
//      ),
//      askAmount: SwapSimulationModel.Amount(
//        amount: BigUInt(),
//        converted: "6,010.01"
//      ),
//      minAskAmount: SwapSimulationModel.Amount(
//        amount: BigUInt(),
//        converted: "6,010.01"
//      ),
//      swapRate: SwapSimulationModel.Rate(value: "0"),
//      info: SwapSimulationModel.Info(
//        priceImpact: "0.001",
//        minimumRecieved: "6,000.01",
//        liquidityProviderFee: "0.0000001",
//        blockchainFee: "0.08 - 0.25 TON",
//        route: SwapSimulationModel.Info.Route(
//          tokenSymbolSend: "TON",
//          tokenSymbolRecieve: "USD₮"
//        ),
//        providerName: "STON.fi"
//      )
//    )
//  )
//}

import Foundation
import TKCore
import KeeperCore

struct SwapConfirmationItem {
  let operationItem: SwapOperationItem
  let simulationModel: SwapSimulationModel
}

extension SwapConfirmationItem {
  static let testData = SwapConfirmationItem(
    operationItem: SwapOperationItem(
      sendToken: .tonStub,
      recieveToken: .usdtStub
    ),
    simulationModel: SwapSimulationModel(
      sendAmount: "",
      recieveAmount: "",
      swapRate: SwapSimulationModel.Rate(value: "0"),
      info: SwapSimulationModel.Info(
        priceImpact: "0.001",
        minimumRecieved: "6,000.01",
        liquidityProviderFee: "0.0000001",
        blockchainFee: "0.08 - 0.25 TON",
        route: SwapSimulationModel.Info.Route(
          tokenSymbolSend: "TON",
          tokenSymbolRecieve: "USD₮"
        ),
        providerName: "STON.fi"
      )
    )
  )
}

protocol SwapConfirmationModuleOutput: AnyObject {
  var didFinish: (() -> Void)? { get set }
  var didTapConfirm: (() -> Void)? { get set }
}

protocol SwapConfirmationModuleInput: AnyObject {
  
}

protocol SwapConfirmationViewModel: AnyObject {
  var didUpdateModel: ((SwapConfirmationView.Model) -> Void)? { get set }
  
  func viewDidLoad()
}

final class SwapConfirmationViewModelImplementation: SwapConfirmationViewModel, SwapConfirmationModuleOutput, SwapConfirmationModuleInput {
  
  // MARK: - SwapConfirmationModuleOutput
  
  var didFinish: (() -> Void)?
  var didTapConfirm: (() -> Void)?
  
  // MARK: - SwapConfirmationModuleInput
  
  
  // MARK: - SwapConfirmationViewModel
  
  var didUpdateModel: ((SwapConfirmationView.Model) -> Void)?
  
  func viewDidLoad() {
    update()
  }
  
  // MARK: - State
  
  private var isResolving = false {
    didSet {
      guard isResolving != oldValue else { return }
      update()
    }
  }
  
  private var isConfirmEnabled: Bool {
    true
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
          balanceTitle: "$ 6,010.01",
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
          balanceTitle: "$ 6,010.01",
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
        isActivity: !isResolving,
        action: { [weak self] in
          self?.didTapConfirm?()
        }
      )
    )
  }
}

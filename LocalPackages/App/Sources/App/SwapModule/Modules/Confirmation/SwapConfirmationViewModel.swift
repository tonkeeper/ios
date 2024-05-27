import Foundation
import KeeperCore
import TKCore

protocol SwapConfirmationViewModel: AnyObject {
  func viewDidLoad()
}

protocol SwapConfirmationModuleOutput: AnyObject {
  var didFinish: (() -> Void)? { get set }
}

protocol SwapConfirmationModuleInput: AnyObject { }

final class SwapConfirmationViewModelImplementation: SwapConfirmationViewModel, SwapConfirmationModuleOutput, SwapConfirmationModuleInput {

  // MARK: - SwapConfirmationModuleOutput
  var didFinish: (() -> Void)?

  init(swapPair: SwapPair,
       swapController: SwapController,
       swapConfirmationController: SwapConfirmationController) {
    self.swapPair = swapPair
    self.swapController = swapController
    self.swapConfirmationController = swapConfirmationController
  }
  
  func viewDidLoad() {
  }

  private let swapPair: SwapPair
  private let swapController: SwapController
  private let swapConfirmationController: SwapConfirmationController
}

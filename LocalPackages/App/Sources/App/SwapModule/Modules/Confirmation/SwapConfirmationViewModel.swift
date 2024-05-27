import Foundation
import KeeperCore
import TKCore

protocol SwapConfirmationViewModel: AnyObject {
  func viewDidLoad()
}

protocol SwapConfirmationModuleOutput: AnyObject {
  var didRequireConfirmation: (() async -> Bool)? { get set }
  var didSendTransaction: (() -> Void)? { get set }
  var didRequireExternalWalletSign: ((URL, Wallet) async throws -> Data?)? { get set }
}

protocol SwapConfirmationModuleInput: AnyObject { }

final class SwapConfirmationViewModelImplementation: SwapConfirmationViewModel, SwapConfirmationModuleOutput, SwapConfirmationModuleInput {

  // MARK: - SwapConfirmationModuleOutput
  var didRequireConfirmation: (() async -> Bool)?
  var didSendTransaction: (() -> Void)?
  var didRequireExternalWalletSign: ((URL, Wallet) async throws -> Data?)?

  init(swapItem: SwapItem,
       swapController: SwapController,
       swapConfirmationController: SwapConfirmationController) {
    self.swapItem = swapItem
    self.swapController = swapController
    self.swapConfirmationController = swapConfirmationController

    self.swapConfirmationController.didGetExternalSign = { [weak self] url in
      guard let self, let didRequireExternalWalletSign else { return Data() }
      return try await didRequireExternalWalletSign(url, swapConfirmationController.wallet)
    }
  }
  
  func viewDidLoad() {
    Task {
      let isSuccess = await self.sendTransaction()
      await MainActor.run {
        if isSuccess {
          didSendTransaction?()
        }
      }
    }
  }

  private let swapItem: SwapItem
  private let swapController: SwapController
  private let swapConfirmationController: SwapConfirmationController

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

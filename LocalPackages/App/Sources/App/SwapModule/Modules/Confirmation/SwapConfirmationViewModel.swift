import Foundation
import KeeperCore
import TKCore

protocol SwapConfirmationViewModel: AnyObject {
  var didUpdateModel: ((SwapView.Model) -> Void)? { get set }
  var didReceiveError: (() -> Void)? { get set }

  func viewDidLoad()
  func didTapConfirm()
  func didTapCancel()
}

protocol SwapConfirmationModuleOutput: AnyObject {
  var didRequireConfirmation: (() async -> Bool)? { get set }
  var didCancel: (() -> Void)? { get set }
  var didSendTransaction: (() -> Void)? { get set }
  var didRequireExternalWalletSign: ((URL, Wallet) async throws -> Data?)? { get set }
}

protocol SwapConfirmationModuleInput: AnyObject { }

final class SwapConfirmationViewModelImplementation: SwapConfirmationViewModel, SwapConfirmationModuleOutput, SwapConfirmationModuleInput {

  // MARK: - SwapConfirmationModuleOutput
  var didRequireConfirmation: (() async -> Bool)?
  var didCancel: (() -> Void)?
  var didSendTransaction: (() -> Void)?
  var didRequireExternalWalletSign: ((URL, Wallet) async throws -> Data?)?

  // MARK: - SwapConfirmationViewModel

  var didUpdateModel: ((SwapView.Model) -> Void)?
  var didReceiveError: (() -> Void)?
  
  func viewDidLoad() {
    didUpdateModel?(swapDetails)
  }

  func didTapCancel() {
    didCancel?()
  }

  func didTapConfirm() {
    Task {
      let isSuccess = await self.sendTransaction()
      await MainActor.run {
        if isSuccess {
          didSendTransaction?()
        } else {
          didReceiveError?()
        }
      }
    }
  }

  init(swapItem: SwapItem,
       swapDetails: SwapView.Model,
       swapConfirmationController: SwapConfirmationController) {
    self.swapItem = swapItem
    self.swapDetails = swapDetails
    self.swapConfirmationController = swapConfirmationController
    self.swapConfirmationController.didGetExternalSign = { [weak self] url in
      guard let self, let didRequireExternalWalletSign else { return Data() }
      return try await didRequireExternalWalletSign(url, swapConfirmationController.wallet)
    }
  }

  private let swapItem: SwapItem
  private let swapDetails: SwapView.Model
  private let swapConfirmationController: SwapConfirmationController
}

private extension SwapConfirmationViewModelImplementation {
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

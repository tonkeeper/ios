import UIKit
import Foundation
import TKUIKit
import TKCore
import BigInt
import TonSwift
import KeeperCore

protocol StakingConfirmationModuleOutput: AnyObject {
  var didRequireConfirmation: (() async -> Bool)? { get set }
  var didFinish: (() -> Void)? { get set }
  var didReceiveInsufficientFunds: ((StakingTransactionSendingStatus.InsufficientFunds) -> Void)? { get set }
}

protocol StakingConfirmationViewModel: AnyObject {
  var didUpdateConfiguration: ((TKModalCardViewController.Configuration) -> Void)? { get set }
  var didUpdateSliderActionModel: ((SliderActionView.Model) -> Void)? { get set }
  var didUpdateSliderLoading: ((Bool) -> Void)? { get set }
  var showToast: ((ToastPresenter.Configuration) -> Void)? { get set }
  
  func viewDidLoad()
}

final class StakingConfirmationViewModelImplementation: StakingConfirmationViewModel, StakingConfirmationModuleOutput {
  
  // MARK: - StakingConfirmationModuleOutput
  
  var didRequireConfirmation: (() async -> Bool)?
  var didUpdateSliderLoading: ((Bool) -> Void)?
  var didReceiveInsufficientFunds: ((StakingTransactionSendingStatus.InsufficientFunds) -> Void)?
  var didFinish: (() -> Void)?

  // MARK: - StakingViewModel
  
  var didUpdateConfiguration: ((TKModalCardViewController.Configuration) -> Void)?
  var didUpdateSliderActionModel: ((SliderActionView.Model) -> Void)?
  var showToast: ((ToastPresenter.Configuration) -> Void)?
  
  func viewDidLoad() {
    setupControllerBindings()
    
    didUpdateSliderActionModel?(createSliderActionModel())
    
    Task {
      await controller.start()
    }
  }
  
  // MARK: - Dependencies
  
  let controller: StakingConfirmationController
  let modelMapper: StakingConfirmationModelMapper
  
  init(controller: StakingConfirmationController, modelMapper: StakingConfirmationModelMapper) {
    self.controller = controller
    self.modelMapper = modelMapper
  }
}

// MARK: - Private methods

private extension StakingConfirmationViewModelImplementation {
  func setupControllerBindings() {
    controller.didUpdateModel = { [weak self] confirmationModel in
      guard let self else { return }
      
      self.didUpdateSliderLoading?(confirmationModel.fee.isLoading)
      
      let configuration = self.modelMapper.map(
        model: confirmationModel
      ) { [weak self] isActivityClosure, isSuccessClosure in
        guard let self = self else { return }
        isActivityClosure(true)
        Task {
          let isSuccess = await self.sendTransaction()
          await MainActor.run {
            isSuccessClosure(isSuccess)
          }
        }
      } completionAction: { [weak self] isSuccess in
        guard isSuccess else { return }
        self?.didFinish?()
      }
      
      self.didUpdateConfiguration?(configuration)
    }
    
    controller.didGetError = { error in
      Task {
        await MainActor.run {
          self.showToast?(self.makeToastConfiguration())
        }
      }
    }
  }
  
  func createSliderActionModel() -> SliderActionView.Model {
    return .init(
      title: String.sliderTitle
    ) { [weak self] loadingClosure, isSuccessClosure in
      guard let self = self else { return }
      
      loadingClosure()
      
      Task {
        let isSuccess = await self.sendTransaction()
        await MainActor.run {
          isSuccessClosure(isSuccess)
        }
      }
    } completionAction: { [weak self] isSuccess in
      guard isSuccess else { return }
      self?.didFinish?()
    }
  }
  
  func sendTransaction() async -> Bool {
    let status = controller.checkTransactionSendingStatus()
    
    switch status {
    case .ready:
      break
    case .feeIsNotSet:
      return false
    case .insufficientFunds(let fundsModel):
      await MainActor.run {
        didReceiveInsufficientFunds?(fundsModel)
      }
      return false
    }
    
    if controller.isNeedToConfirm() {
      let isConfirmed = await didRequireConfirmation?() ?? false
      guard isConfirmed else { return false }
    }
    
    do {
      try await controller.sendTransaction()
      return true
    } catch {
      return false
    }
  }
  
  func makeToastConfiguration() -> ToastPresenter.Configuration {
    .init(
      title: "Failed to sign. Try one more time",
      backgroundColor: .Background.contentTint,
      foregroundColor: .Text.primary
    )
  }
}

private extension String {
  static let sliderTitle = "Slide to confirm"
}

private extension LoadableModelItem<String> {
  var isLoading: Bool {
    switch self {
    case .loading:
      return true
    case .value:
      return false
    }
  }
}

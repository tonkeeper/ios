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
}

protocol StakingConfirmationViewModel: AnyObject {
  var didUpdateConfiguration: ((TKModalCardViewController.Configuration) -> Void)? { get set }
  var didUpdateSliderActionModel: ((SliderActionView.Model) -> Void)? { get set }
  
  func viewDidLoad()
}

final class StakingConfirmationViewModelImplementation: StakingConfirmationViewModel, StakingConfirmationModuleOutput {
  
  // MARK: - StakingConfirmationModuleOutput
  
  var didRequireConfirmation: (() async -> Bool)?
  var didFinish: (() -> Void)?

  // MARK: - StakingViewModel
  
  var didUpdateConfiguration: ((TKModalCardViewController.Configuration) -> Void)?
  var didUpdateSliderActionModel: ((SliderActionView.Model) -> Void)?
  
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
      print("[PAG] Handle \(error)")
    }
  }
  
  func createSliderActionModel() -> SliderActionView.Model {
    let title = String.sliderTitle.withTextStyle(
      .label1,
      color: .Text.secondary
    )
    
    return .init(
      title: title
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
}

private extension String {
  static let sliderTitle = "Slide to confirm"
}

import UIKit
import Foundation
import TKUIKit
import TKCore
import BigInt
import TonSwift
import KeeperCore

protocol StakingConfirmationModuleOutput: AnyObject {
  var didRequireConfirmation: (() async -> Bool)? { get set }
  var didPerformStaking: (() -> Void)? { get set }
}

protocol StakingConfirmationViewModel: AnyObject {
  var didUpdateConfiguration: ((TKModalCardViewController.Configuration) -> Void)? { get set }
  func viewDidLoad()
}

final class StakingConfirmationViewModelImplementation: StakingConfirmationViewModel, StakingConfirmationModuleOutput {
  
  // MARK: - StakingConfirmationModuleOutput
  
  var didPerformStaking: (() -> Void)?
  var didRequireConfirmation: (() async -> Bool)?
  
  // MARK: - StakingViewModel
  
  var didUpdateConfiguration: ((TKModalCardViewController.Configuration) -> Void)?
  
  func viewDidLoad() {
    setupControllerBindings()
    
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
        model: confirmationModel) { [weak self] isActivityClosure, isSuccessClosure in
          guard let self = self else { return }
          isActivityClosure(true)
          Task {
            let isSuccess = await self.performStaking()
            await MainActor.run {
               isSuccessClosure(isSuccess)
            }
          }
        } completionAction: { [weak self] isSuccess in
          guard isSuccess else { return }
          
          self?.didPerformStaking?()
        }

      self.didUpdateConfiguration?(configuration)
    }
  }
  
  func performStaking() async -> Bool {
    let isConfirmed = await didRequireConfirmation?() ?? false
    if !isConfirmed {
      return false
    }
    
    try? await Task.sleep(nanoseconds: 1_000_000_000)
    return true
  }
}

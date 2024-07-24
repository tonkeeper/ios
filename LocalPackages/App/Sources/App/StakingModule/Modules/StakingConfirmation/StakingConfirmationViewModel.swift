import UIKit
import TKUIKit
import KeeperCore
import TKCore
import TKLocalize
import TonSwift

protocol StakingConfirmationModuleOutput: AnyObject {
  var didSendTransaction: (() -> Void)? { get set }
  var didRequireSign: ((TransferMessageBuilder, Wallet) async throws -> String?)? { get set }
}

protocol StakingConfirmationModuleInput: AnyObject {
  
}

protocol StakingConfirmationViewModel: AnyObject {
  var didUpdateConfiguration: ((TKModalCardViewController.Configuration) -> Void)? { get set }
  
  func viewDidLoad()
  func viewDidAppear()
  func viewWillDisappear()
}

final class StakingConfirmationViewModelImplementation: StakingConfirmationViewModel, StakingConfirmationModuleOutput, StakingConfirmationModuleInput {
  
  // MARK: - StakingConfirmationModuleOutput
  
  var didSendTransaction: (() -> Void)?
  
  var didRequireSign: ((TransferMessageBuilder, Wallet) async throws -> String?)?
  
  // MARK: - StakingConfirmationModuleInput
  
  // MARK: - StakingConfirmationViewModel
  
  var didUpdateConfiguration: ((TKModalCardViewController.Configuration) -> Void)?
  
  func viewDidLoad() {
    setupControllerBindings()
    Task {
      await stakingConfirmationController.start()
    }
  }
  
  func viewDidAppear() {
    
  }
  
  func viewWillDisappear() {
    
  }
  
  // MARK: - Dependencies
  
  private let stakingConfirmationController: StakeConfirmationController
  
  // MARK: - Mapper
  
  private let mapper = StakingConfirmationMapper()
  
  // MARK: - Init
  
  init(stakingConfirmationController: StakeConfirmationController) {
    self.stakingConfirmationController = stakingConfirmationController
  }
}

private extension StakingConfirmationViewModelImplementation {
  func setupControllerBindings() {
    stakingConfirmationController.didUpdateModel = { [weak self] StakingConfirmationModel in
      guard let self else { return }
      let configuration = self.mapStakingConfirmationModel(StakingConfirmationModel)
      self.didUpdateConfiguration?(configuration)
    }
    
    stakingConfirmationController.signHandler = { [weak self] transferBuilder, wallet in
      try await self?.didRequireSign?(transferBuilder, wallet)
    }
  }
  
  func mapStakingConfirmationModel(_ stakingConfirmationModel: StakeConfirmationModel) -> TKModalCardViewController.Configuration {
    return mapper.map(
      model: stakingConfirmationModel) { [weak self] isActivityClosure, isSuccessClosure in
        guard let self = self else { return }
        isActivityClosure(true)
        Task {
          let isSuccess = await self.sendTransaction()
          await MainActor.run {
            isSuccessClosure(isSuccess)
          }
        }
      } completionAction: { [weak self] isSuccess in
        guard let self, isSuccess else { return }
        self.didSendTransaction?()
      }
  }
  
  func sendTransaction() async -> Bool {
    do {
      try await stakingConfirmationController.sendTransaction()
      return true
    } catch {
      return false
    }
  }
}

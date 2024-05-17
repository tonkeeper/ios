import UIKit
import TKCoordinator
import TKUIKit
import TKScreenKit
import TKCore
import KeeperCore

final class StakingCoordinator: RouterCoordinator<NavigationControllerRouter> {
  var didFinish: (() -> Void)?
  
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  private let coreAssembly: TKCore.CoreAssembly
  
  init(
    keeperCoreMainAssembly: KeeperCore.MainAssembly,
    coreAssembly: TKCore.CoreAssembly,
    router: NavigationControllerRouter
  ) {
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    self.coreAssembly = coreAssembly
    
    super.init(router: router)
  }
  
  override func start() {
    let stakingModule = StakingAssembly.module(keeperCoreMainAssembly: keeperCoreMainAssembly)
//    let vc = TestVC()
//    router.push(viewController: vc, animated: false)
    
    stakingModule.view.setupRightCloseButton { [weak self] in
      self?.didFinish?()
    }
    
    stakingModule.view.setupButton(icon: UIImage.TKUIKit.Icons.Size16.infoCircle, position: .left) {
      print("open warning")
    }

    stakingModule.output.didTapProviderPicker = { [weak self] in
      let optionsOutput = self?.openOptions()
      optionsOutput?.didChooseOption = { item in
        stakingModule.input.setOption(item)
      }
      
      optionsOutput?.didTapOptionDetails = { item in
        let detailsOutput = self?.openOptionDetails(item: item)
        
        detailsOutput?.didChooseOption = { [weak self] item in
          stakingModule.input.setOption(item)
          self?.router.popTo(viewController: stakingModule.view, animated: true, completion: nil)
        }
      }
    }
    
    stakingModule.output.didTapContinue = { [weak self] wallet in
      let confirmOutput = self?.openConfirm(wallet: wallet, operation: .stake)
      confirmOutput?.didPerformStaking = {
        print("Successfully perform staking operation")
      }
      
      confirmOutput?.didRequireConfirmation = { [weak self] in
        guard let self else { return false }
        
        return await self.openPasscode(fromViewController: self.router.rootViewController)
      }
    }
    
    router.push(viewController: stakingModule.view, animated: false)
  }
  
  func openConfirm(wallet: Wallet, operation: StakingOperation) -> StakingConfirmationModuleOutput {
    let module = StakingConfirmationAssembly.module(operation: operation, wallet: wallet, keeperCoreMainAssembly: keeperCoreMainAssembly)
    
    module.view.setupRightCloseButton { [weak self] in
      self?.didFinish?()
    }
    
    router.push(viewController: module.view)
    
    return module.output
  }
  
  func openOptions() -> StakingOptionsModuleOutput {
    let module = StakingOptionsAssembly.module(keeperCoreMainAssembly: keeperCoreMainAssembly)
    
    module.view.setupRightCloseButton { [weak self] in
      self?.didFinish?()
    }
    
    router.push(viewController: module.view)
    
    return module.output
  }
  
  func openOptionDetails(item: OptionItem) -> StakingOptionDetailsModuleOutput {
    let module = StakingOptionDetailsAssembly.module(
      item: item,
      keeperCoreMainAssembly: keeperCoreMainAssembly,
      urlOpener: coreAssembly.urlOpener()
    )
    
    module.view.setupRightCloseButton { [weak self] in
      self?.didFinish?()
    }
    
    router.push(viewController: module.view)
    
    return module.output
  }
  
  func openPasscode(fromViewController: UIViewController) async -> Bool {
    return await Task<Bool, Never> { @MainActor in
      return await withCheckedContinuation { [weak self, keeperCoreMainAssembly] (continuation: CheckedContinuation<Bool, Never>) in
        guard let self = self else { return }
        let coordinator = PasscodeModule(
          dependencies: PasscodeModule.Dependencies(
            passcodeAssembly: keeperCoreMainAssembly.passcodeAssembly
          )
        ).passcodeConfirmationCoordinator()
        
        coordinator.didCancel = { [weak self, weak coordinator] in
          continuation.resume(returning: false)
          coordinator?.router.dismiss(completion: {
            guard let coordinator else { return }
            self?.removeChild(coordinator)
          })
        }
        
        coordinator.didConfirm = { [weak self, weak coordinator] in
          continuation.resume(returning: true)
          coordinator?.router.dismiss(completion: {
            guard let coordinator else { return }
            self?.removeChild(coordinator)
          })
        }
        
        self.addChild(coordinator)
        coordinator.start()
        
        fromViewController.present(coordinator.router.rootViewController, animated: true)
      }
    }.value
  }
}

import UIKit
import TKCoordinator
import TKUIKit

public final class OnboardingCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  public var didFinishOnboarding: (() -> Void)?

  public override func start() {
    openOnboardingStart()
  }
}

private extension OnboardingCoordinator {
  func openOnboardingStart() {
    let module = OnboardingRootAssembly.module()
    
    module.output.didTapCreateButton = { [weak self] in
      self?.openCreate()
    }
    
    module.output.didTapImportButton = { [weak self] in
      self?.openImport()
    }
    
    router.push(viewController: module.view, animated: false)
  }
  
  func openCreate() {
    let coordinator = CreateWalletCoordinator(router: router)
    coordinator.didCancel = { [weak self, weak coordinator] in
      guard let coordinator = coordinator else { return }
      self?.removeChild(coordinator)
    }
    
    coordinator.didCreateWallet = { [weak self, weak coordinator] in
      guard let coordinator = coordinator else { return }
      self?.removeChild(coordinator)
      self?.didFinishOnboarding?()
    }
    
    addChild(coordinator)
    coordinator.start()
  }
  
  func openImport() {
    let coordinator = ImportWalletCoordinator(router: router)
    coordinator.didCancel = { [weak self, weak coordinator] in
      guard let coordinator = coordinator else { return }
      self?.removeChild(coordinator)
    }
    
    coordinator.didImportWallet = { [weak self, weak coordinator] in
      guard let coordinator = coordinator else { return }
      self?.removeChild(coordinator)
      self?.didFinishOnboarding?()
    }
    
    addChild(coordinator)
    coordinator.start()
  }
}

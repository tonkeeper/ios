import UIKit
import TKCoordinator
import TKUIKit
import KeeperCore

public final class OnboardingCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  private let keeperCoreOnboardingAssembly: KeeperCore.OnboardingAssembly
  
  public var didFinishOnboarding: (() -> Void)?
  
  init(router: NavigationControllerRouter,
       keeperCoreOnboardingAssembly: KeeperCore.OnboardingAssembly) {
    self.keeperCoreOnboardingAssembly = keeperCoreOnboardingAssembly
    super.init(router: router)
  }
  
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
    let navigationController = TKNavigationController()
    navigationController.configureTransparentAppearance()
    navigationController.isModalInPresentation = true
    
    let coordinator = CreateWalletCoordinator(
      router: NavigationControllerRouter(rootViewController: navigationController),
      walletAddController: keeperCoreOnboardingAssembly.walletAddController()
    )
    coordinator.didCancel = { [weak self, weak coordinator, weak navigationController] in
      guard let coordinator = coordinator else { return }
      self?.removeChild(coordinator)
      navigationController?.dismiss(animated: true)
    }
    
    coordinator.didCreateWallet = { [weak self, weak coordinator] in
      guard let coordinator = coordinator else { return }
      self?.removeChild(coordinator)
      self?.didFinishOnboarding?()
      navigationController.dismiss(animated: true)
    }
    
    addChild(coordinator)
    coordinator.start()
    
    router.present(navigationController)
  }
  
  func openImport() {
    let navigationController = TKNavigationController()
    navigationController.configureTransparentAppearance()
    navigationController.isModalInPresentation = true
    
    let coordinator = ImportWalletCoordinator(
      router: NavigationControllerRouter(rootViewController: navigationController),
      walletAddController: keeperCoreOnboardingAssembly.walletAddController()
    )
    coordinator.didCancel = { [weak self, weak coordinator, weak navigationController] in
      guard let coordinator = coordinator else { return }
      self?.removeChild(coordinator)
      navigationController?.dismiss(animated: true)
    }
    
    coordinator.didImportWallet = { [weak self, weak coordinator] in
      guard let coordinator = coordinator else { return }
      self?.removeChild(coordinator)
      self?.didFinishOnboarding?()
      navigationController.dismiss(animated: true)
    }
    
    addChild(coordinator)
    coordinator.start()
    
    router.present(navigationController)
  }
}

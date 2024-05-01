import UIKit
import TKUIKit
import SignerCore

final class RootCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  private let signerCoreAssembly: SignerCore.Assembly
  private let rootController: RootController

  init(router: NavigationControllerRouter,
                signerCoreAssembly: SignerCore.Assembly) {
    self.signerCoreAssembly = signerCoreAssembly
    self.rootController = signerCoreAssembly.rootController()
    super.init(router: router)
    router.rootViewController.setNavigationBarHidden(true, animated: false)
  }
  
  override func start() {
    func handleState(state: RootController.State) {
      switch state {
      case .onboarding:
        openOnboarding()
      case .main:
        openMain()
      }
    }
    handleState(state: rootController.getState())
    
    rootController.didUpdateState = {state in
      handleState(state: state)
    }
    rootController.start()
  }
}

private extension RootCoordinator {
  func openOnboarding() {
    let navigationController = NavigationController()
    navigationController.configureTransparentAppearance()

    let onboardingCoordinator = OnboardingCoordinator(
      router: .init(rootViewController: navigationController),
      signerCoreAssembly: signerCoreAssembly
    )
    onboardingCoordinator.didCompleteOnboarding = { [weak self, unowned onboardingCoordinator] in
      self?.removeChild(onboardingCoordinator)
      self?.openMain()
    }
    addChild(onboardingCoordinator)
    onboardingCoordinator.start()
    
    showViewController(navigationController, animated: false)
  }
  
  func openEnterPassword() {
    let navigationController = NavigationController()
    navigationController.configureTransparentAppearance()
    
    let enterPasswordCoodinator = EnterPasswordCoordinator(
      router: NavigationControllerRouter(
        rootViewController: navigationController
      ),
      assembly: signerCoreAssembly
    )
    enterPasswordCoodinator.didEnterPassword = { [weak self, unowned enterPasswordCoodinator] in
      self?.removeChild(enterPasswordCoodinator)
      self?.openMain()
    }
    enterPasswordCoodinator.didSignOut = { [weak self, unowned enterPasswordCoodinator] in
      self?.removeChild(enterPasswordCoodinator)
      self?.openOnboarding()
    }
    addChild(enterPasswordCoodinator)
    enterPasswordCoodinator.start()
    
    showViewController(navigationController, animated: false)
  }
  
  func openMain() {
    let navigationController = NavigationController()
    navigationController.configureDefaultAppearance()

    let mainCoordinator = MainCoordinator(
      router: .init(rootViewController: navigationController),
      signerCoreAssembly: signerCoreAssembly
    )
    addChild(mainCoordinator)
    mainCoordinator.start()
    
    showViewController(navigationController, animated: true)
  }
  
  func showViewController(_ viewController: UIViewController, animated: Bool) {
    let containerViewController = UIViewController()
    containerViewController.addChild(viewController)
    containerViewController.view.addSubview(viewController.view)
    viewController.didMove(toParent: containerViewController)

    viewController.view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      viewController.view.topAnchor.constraint(equalTo: containerViewController.view.topAnchor),
      viewController.view.leftAnchor.constraint(equalTo: containerViewController.view.leftAnchor),
      viewController.view.bottomAnchor.constraint(equalTo: containerViewController.view.bottomAnchor),
      viewController.view.rightAnchor.constraint(equalTo: containerViewController.view.rightAnchor)
    ])
    
    router.push(viewController: containerViewController, animated: animated)
  }
}

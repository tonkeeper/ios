import UIKit
import TKUIKit
import TKCoordinator
import OnboardingModule
import MainModule

final class RootCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  var hasWallet = true

  override init(router: NavigationControllerRouter) {
    super.init(router: router)
    router.rootViewController.setNavigationBarHidden(true, animated: false)
  }
  
  override func start() {
    if hasWallet {
      openMain()
    } else {
      openOnboarding()
    }
  }
}

private extension RootCoordinator {
  func openOnboarding() {
    let onboarding = OnboardingModule()
    let coordinator = onboarding.createOnboardingCoordinator()
    
    coordinator.didFinishOnboarding = { [weak self, weak coordinator] in
      guard let coordinator = coordinator else { return }
      self?.removeChild(coordinator)
      self?.hasWallet = true
      self?.start()
    }
    
    addChild(coordinator)
    coordinator.start()
    
    showViewController(coordinator.router.rootViewController, animated: true)
  }
  
  func openMain() {
    let module = MainModule()
    let coordinator = module.createMainCoordinator()
    
    addChild(coordinator)
    coordinator.start()
    
    showViewController(coordinator.router.rootViewController, animated: true)
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
    
//    router.push(viewController: containerViewController, animated: animated)
//    router.setViewControllers([containerViewController], animated: animated)
    router.setViewControllers([(containerViewController , nil)])
  }
}

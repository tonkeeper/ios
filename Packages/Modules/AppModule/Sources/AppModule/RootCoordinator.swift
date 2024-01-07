import UIKit
import TKUIKit
import TKCoordinator
import Onboarding

final class RootCoordinator: RouterCoordinator<NavigationControllerRouter> {

  override init(router: NavigationControllerRouter) {
    super.init(router: router)
    router.rootViewController.setNavigationBarHidden(true, animated: false)
  }
  
  override func start() {
    openOnboarding()
  }
}

private extension RootCoordinator {
  func openOnboarding() {
    let onboarding = Onboarding()
    let coordinator = onboarding.createOnboardingCoordinator()
    
    addChild(coordinator)
    coordinator.start()
    
    showViewController(coordinator.router.rootViewController, animated: true)
  }
  
  func openMain() {
    
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

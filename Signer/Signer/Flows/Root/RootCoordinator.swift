import UIKit
import TKUIKit
import TKCoordinator
import SignerCore

final class RootCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  private let signerCoreAssembly: SignerCore.Assembly
  private let rootController: RootController
  
  private weak var mainCoordinator: MainCoordinator?
  private weak var passwordCoordinator: EnterPasswordCoordinator?
  private var deeplink: CoordinatorDeeplink?

  init(router: NavigationControllerRouter,
                signerCoreAssembly: SignerCore.Assembly) {
    self.signerCoreAssembly = signerCoreAssembly
    self.rootController = signerCoreAssembly.rootController()
    super.init(router: router)
    router.rootViewController.setNavigationBarHidden(true, animated: false)
  }
  
  override func start(deeplink: CoordinatorDeeplink? = nil) {
    func handleState(state: RootController.State) {
      switch state {
      case .onboarding:
        openOnboarding()
      case .main:
        self.deeplink = deeplink
        openMain(deeplink: deeplink)
      }
    }
    handleState(state: rootController.getState())
    
    rootController.didUpdateState = {state in
      DispatchQueue.main.async {
        handleState(state: state)
      }
    }
    rootController.start()
  }
  
  override func handleDeeplink(deeplink: CoordinatorDeeplink?) -> Bool {
    if let mainCoordinator {
      return mainCoordinator.handleDeeplink(deeplink: deeplink)
    }
    self.deeplink = deeplink
    return false
  }
}

private extension RootCoordinator {
  func openOnboarding() {
    let navigationController = TKNavigationController()
    navigationController.configureTransparentAppearance()

    let onboardingCoordinator = OnboardingCoordinator(
      router: .init(rootViewController: navigationController),
      signerCoreAssembly: signerCoreAssembly
    )
    onboardingCoordinator.didCompleteOnboarding = { [weak self, unowned onboardingCoordinator] in
      self?.removeChild(onboardingCoordinator)
      self?.openMain(deeplink: nil)
    }
    addChild(onboardingCoordinator)
    onboardingCoordinator.start()
    
    showViewController(navigationController, animated: false)
  }
  
  func openMain(deeplink: CoordinatorDeeplink?) {
    let navigationController = TKNavigationController()
    navigationController.configureDefaultAppearance()

    let mainCoordinator = MainCoordinator(
      router: .init(rootViewController: navigationController),
      signerCoreAssembly: signerCoreAssembly
    )
    
    self.mainCoordinator = mainCoordinator
    
    addChild(mainCoordinator)
    mainCoordinator.start(deeplink: deeplink)
    
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
    
    router.rootViewController.setViewControllers([containerViewController], animated: true)
  }
}

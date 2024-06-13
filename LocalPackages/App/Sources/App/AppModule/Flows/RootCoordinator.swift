import UIKit
import TKUIKit
import TKCoordinator
import TKCore
import KeeperCore

final class RootCoordinator: RouterCoordinator<NavigationControllerRouter> {
  struct Dependencies {
    let coreAssembly: TKCore.CoreAssembly
    let keeperCoreRootAssembly: KeeperCore.RootAssembly
  }
  
  private weak var onboardingCoordinator: OnboardingCoordinator?
  private weak var mainCoordinator: MainCoordinator?
  
  private let dependencies: Dependencies
  private let rootController: RootController

  init(router: NavigationControllerRouter,
       dependencies: Dependencies) {
    self.dependencies = dependencies
    self.rootController = dependencies.keeperCoreRootAssembly.rootController()
    super.init(router: router)
    router.rootViewController.setNavigationBarHidden(true, animated: false)
  }
  
  override func start(deeplink: CoordinatorDeeplink? = nil) {
    KeeperInfoMigration(
      keeperInfoDirectory: dependencies.coreAssembly.sharedCacheURL,
      sharedKeychainGroup: dependencies.coreAssembly.keychainAccessGroupIdentifier
    ).migrateKeeperInfoIfNeeded()
    
    rootController.loadConfiguration()
    rootController.loadKnownAccounts()
    rootController.loadBuySellMethods()

      switch rootController.getState() {
      case .onboarding:
        openOnboarding(deeplink: try? rootController.parseDeeplink(string: deeplink?.string))
      case let .main(wallets, activeWallet):
        openMain(wallets: wallets, activeWallet: activeWallet, deeplink: try? rootController.parseDeeplink(string: deeplink?.string))
      }
  }
  
  override func handleDeeplink(deeplink: CoordinatorDeeplink?) -> Bool {
    do {
      let coreDeeplink = try rootController.parseDeeplink(string: deeplink?.string)
      if let onboardingCoordinator {
        return onboardingCoordinator.handleDeeplink(deeplink: coreDeeplink)
      } else if let mainCoordinator {
        return mainCoordinator.handleDeeplink(deeplink: coreDeeplink)
      } else {
        return false
      }
    } catch {
      return false
    }
  }
}

private extension RootCoordinator {
  func openOnboarding(deeplink: CoordinatorDeeplink?) {
    let module = OnboardingModule(
      dependencies: OnboardingModule.Dependencies(
        coreAssembly: dependencies.coreAssembly,
        keeperCoreOnboardingAssembly: dependencies.keeperCoreRootAssembly.onboardingAssembly()
      )
    )
    let coordinator = module.createOnboardingCoordinator()
    
    coordinator.didFinishOnboarding = { [weak self, weak coordinator] in
      self?.onboardingCoordinator = nil
      guard let coordinator = coordinator else { return }
      self?.removeChild(coordinator)
      self?.start(deeplink: nil)
    }
    
    self.onboardingCoordinator = coordinator
    
    addChild(coordinator)
    coordinator.start(deeplink: deeplink)
    
    showViewController(coordinator.router.rootViewController, animated: true)
  }
  
  func openMain(wallets: [Wallet], activeWallet: Wallet, deeplink: CoordinatorDeeplink?) {
    let mainAssemblyDependencies = MainAssembly.Dependencies(
      wallets: wallets, 
      activeWallet: activeWallet
    )
    let module = MainModule(
      dependencies: MainModule.Dependencies(
        coreAssembly: dependencies.coreAssembly,
        keeperCoreMainAssembly: dependencies.keeperCoreRootAssembly.mainAssembly(
          dependencies: mainAssemblyDependencies
        )
      )
    )
    let coordinator = module.createMainCoordinator()
    coordinator.didLogout = { [weak self, weak coordinator] in
      self?.mainCoordinator = nil
      guard let self, let coordinator else { return }
      Task {
        await self.rootController.logout()
        await MainActor.run {
          self.start(deeplink: nil)
          self.removeChild(coordinator)
        }
      }
    }
    self.mainCoordinator = coordinator
    
    addChild(coordinator)
    coordinator.start(deeplink: deeplink)
    
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
    router.setViewControllers([(containerViewController , nil)], animated: animated)
  }
}

extension KeeperCore.Deeplink: TKCoordinator.CoordinatorDeeplink {}
extension KeeperCore.TonkeeperDeeplink: TKCoordinator.CoordinatorDeeplink {}
extension KeeperCore.TonkeeperDeeplink.SignerDeeplink: TKCoordinator.CoordinatorDeeplink {}

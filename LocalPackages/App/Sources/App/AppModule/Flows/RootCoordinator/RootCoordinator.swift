import UIKit
import TKUIKit
import TKCoordinator
import TKCore
import KeeperCore

final class RootCoordinator: RouterCoordinator<ViewControllerRouter> {
  struct Dependencies {
    let coreAssembly: TKCore.CoreAssembly
    let keeperCoreRootAssembly: KeeperCore.RootAssembly
  }
  
  private weak var onboardingCoordinator: OnboardingCoordinator?
  private weak var mainCoordinator: MainCoordinator?
  
  private var activeViewController: UIViewController?
  
  private let dependencies: Dependencies
  private let rootController: RootController
  
  private let stateManager: RootCoordinatorStateManager

  init(router: ViewControllerRouter,
       dependencies: Dependencies) {
    self.dependencies = dependencies
    self.rootController = dependencies.keeperCoreRootAssembly.rootController()
    self.stateManager = RootCoordinatorStateManager(
      keeperInfoStore: dependencies.keeperCoreRootAssembly.storesAssembly.keeperInfoStore
    )
    super.init(router: router)
  }
  
  override func start(deeplink: CoordinatorDeeplink? = nil) {
    rootController.loadConfiguration()
    rootController.loadKnownAccounts()
    rootController.loadBuySellMethods()
    
    stateManager.didUpdateState = { [weak self] state in
      self?.handleStateUpdate(state: state, deeplink: deeplink)
    }
    
    let state = stateManager.state
    switch state {
    case .onboarding:
      openLaunchScreen()
      let migrationController = dependencies.keeperCoreRootAssembly.migrationController(
        sharedCacheURL: dependencies.coreAssembly.sharedCacheURL,
        keychainAccessGroupIdentifier: dependencies.coreAssembly.keychainAccessGroupIdentifier,
        isTonkeeperX: dependencies.coreAssembly.isTonkeeperX
      )
      Task {
        if await migrationController.checkIfNeedToMigrate() {
          await MainActor.run {
            openMigration(migrationController: migrationController)
          }
        } else {
          await MainActor.run {
            openOnboarding(deeplink: deeplink)
          }
        }
      }
    case .main(let walletsState):
      openMain(wallets: walletsState.wallets, activeWallet: walletsState.activeWallet, deeplink: deeplink)
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
  func handleStateUpdate(state: RootCoordinatorStateManager.State, deeplink: CoordinatorDeeplink? = nil) {
    self.mainCoordinator = nil
    self.onboardingCoordinator = nil
    switch state {
    case .onboarding:
      openOnboarding(deeplink: deeplink)
    case .main(let walletsState):
      openMain(wallets: walletsState.wallets, activeWallet: walletsState.activeWallet, deeplink: deeplink)
    }
  }
  
  func openLaunchScreen() {
    let viewController = LaunchScreenViewController()
    showViewController(viewController, animated: false)
  }
  
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
      guard let self, let coordinator else { return }
      Task {
        do {
          try await self.logout()
          self.removeChild(coordinator)
        } catch {
          print("Log: Logout failed")
        }
      }
    }
    self.mainCoordinator = coordinator
    
    addChild(coordinator)
    coordinator.start(deeplink: deeplink)
    
    let navigationController = TKNavigationController(rootViewController: coordinator.router.rootViewController)
    navigationController.configureDefaultAppearance()
      
    showViewController(navigationController, animated: true)
  }
  
  func openMigration(migrationController: MigrationController) {
    let navigationController = TKNavigationController()
    navigationController.configureTransparentAppearance()
    
    let migrationCoordinator = MigrationCoordinator(
      migrationController: migrationController,
      rnService: dependencies.keeperCoreRootAssembly.rnAssembly.rnService,
      router: NavigationControllerRouter(rootViewController: navigationController)
    )
    migrationCoordinator.didFinish = { [weak self, weak migrationCoordinator] in
      self?.removeChild(migrationCoordinator)
      self?.start(deeplink: nil)
    }
    migrationCoordinator.didLogout = { [weak self, weak migrationCoordinator] in
      guard let self, let migrationCoordinator else { return }
      Task {
        do {
          try await self.logout()
          self.removeChild(migrationCoordinator)
        } catch {
          print("Log: Logout failed")
        }
      }
    }
    addChild(migrationCoordinator)
    migrationCoordinator.start(deeplink: nil)
    
    showViewController(navigationController, animated: false)
  }
  
  func showViewController(_ viewController: UIViewController, animated: Bool) {
    activeViewController?.willMove(toParent: nil)
    activeViewController?.view.removeFromSuperview()
    activeViewController?.removeFromParent()
    
    activeViewController = viewController
    
    router.rootViewController.addChild(viewController)
    router.rootViewController.view.addSubview(viewController.view)
    viewController.didMove(toParent: router.rootViewController)
    
    viewController.view.snp.makeConstraints { make in
      make.edges.equalTo(router.rootViewController.view)
    }
    
    if animated {
      UIView.transition(with: router.rootViewController.view, duration: 0.2, options: .transitionCrossDissolve) {}
    }
  }
  
  func logout() async throws {
    try await self.rootController.logout()
    await MainActor.run {
      self.mainCoordinator = nil
      self.start(deeplink: nil)
    }
  }
}

extension KeeperCore.Deeplink: TKCoordinator.CoordinatorDeeplink {}
extension KeeperCore.TonkeeperDeeplink: TKCoordinator.CoordinatorDeeplink {}
extension KeeperCore.TonkeeperDeeplink.SignerDeeplink: TKCoordinator.CoordinatorDeeplink {}

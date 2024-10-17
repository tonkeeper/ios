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
  private let featureFlagsProvider: FeatureFlagsProvider
  private let pushNotificationsManager: PushNotificationManager
  private let rnUpdater: RNUpdater

  init(router: ViewControllerRouter,
       dependencies: Dependencies) {
    self.dependencies = dependencies
    self.rootController = dependencies.keeperCoreRootAssembly.rootController()
    self.stateManager = RootCoordinatorStateManager(
      walletsStore: dependencies.keeperCoreRootAssembly.storesAssembly.walletsStore
    )
    self.featureFlagsProvider = dependencies.coreAssembly.featureFlagsProvider
    self.pushNotificationsManager = PushNotificationManager(
      appSettings: dependencies.coreAssembly.appSettings,
      pushNotificationTokenProvider: dependencies.coreAssembly.pushNotificationTokenProvider,
      pushNotificationAPI: dependencies.coreAssembly.pushNotificationAPI,
      walletNotificationsStore: dependencies.keeperCoreRootAssembly.storesAssembly.walletNotificationStore
    )
    self.rnUpdater = RNUpdater(
      rnService: dependencies.keeperCoreRootAssembly.rnAssembly.rnService,
      keeperInfoStore: dependencies.keeperCoreRootAssembly.storesAssembly.keeperInfoStore
    )
    super.init(router: router)
  }
  
  override func start(deeplink: CoordinatorDeeplink? = nil) {
    pushNotificationsManager.setup()
    
    featureFlagsProvider.didUpdateIsMarketRegionPickerAvailable = { [weak self, weak featureFlagsProvider] in
      guard let isMarketRegionPickerAvailable = featureFlagsProvider?.isMarketRegionPickerAvailable else { return }
      self?.rootController.loadFiatMethods(isMarketRegionPickerAvailable: isMarketRegionPickerAvailable)
    }
    rootController.loadFiatMethods(isMarketRegionPickerAvailable: featureFlagsProvider.isMarketRegionPickerAvailable)
    
    rootController.loadConfigurations()
    
    stateManager.didUpdateState = { [weak self] state in
      self?.handleStateUpdate(state: state, deeplink: deeplink)
    }
    
    let state = stateManager.state
    switch state {
    case .onboarding:
      openLaunchScreen()
      migrateIfNeed(deeplink: deeplink)
    case .main:
      migrateTonConnectVaultIfNeeded()
      openMain(deeplink: deeplink)
    }
  }
  
  override func handleDeeplink(deeplink: CoordinatorDeeplink?) -> Bool {
    guard let string = deeplink as? String else { return false }
    do {
      let coreDeeplink = try rootController.parseDeeplink(string: string)
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
    removeChild(mainCoordinator)
    removeChild(onboardingCoordinator)
    self.mainCoordinator = nil
    self.onboardingCoordinator = nil
    switch state {
    case .onboarding:
      openOnboarding(deeplink: deeplink)
    case .main:
      openMain(deeplink: deeplink)
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
    }
    
    self.onboardingCoordinator = coordinator
    
    addChild(coordinator)
    coordinator.start(deeplink: deeplink)
    
    showViewController(coordinator.router.rootViewController, animated: true)
  }
  
  func openMain(deeplink: CoordinatorDeeplink?) {
    let module = MainModule(
      dependencies: MainModule.Dependencies(
        coreAssembly: dependencies.coreAssembly,
        keeperCoreMainAssembly: dependencies.keeperCoreRootAssembly.mainAssembly()
      )
    )
    let coordinator = module.createMainCoordinator()
    self.mainCoordinator = coordinator
    
    addChild(coordinator)
    coordinator.start(deeplink: deeplink)
    
    let navigationController = TKNavigationController(rootViewController: coordinator.router.rootViewController)
    navigationController.configureDefaultAppearance()
      
    showViewController(navigationController, animated: true)
  }
  
  // TODO: Delete after open beta
  
  func migrateTonConnectVaultIfNeeded() {
    guard !dependencies.coreAssembly.appSettings.didMigrateTonConnectAppVault else { return }
    let wallets = dependencies.keeperCoreRootAssembly.storesAssembly.walletsStore.wallets
    dependencies.keeperCoreRootAssembly.mainAssembly().tonConnectAssembly.tonConnectService().migrateTonConnectAppsVault(wallets: wallets)
    dependencies.coreAssembly.appSettings.didMigrateTonConnectAppVault = true
  }
  
  func migrateIfNeed(deeplink: CoordinatorDeeplink?) {
    let rnMigration = RNMigration(
      rnService: dependencies.keeperCoreRootAssembly.rnAssembly.rnService,
      walletsStore: dependencies.keeperCoreRootAssembly.storesAssembly.walletsStore,
      securityStore: dependencies.keeperCoreRootAssembly.storesAssembly.securityStore,
      currencyStore: dependencies.keeperCoreRootAssembly.storesAssembly.currencyStore,
      walletNotificationStore: dependencies.keeperCoreRootAssembly.storesAssembly.walletNotificationStore
    )
    Task {
      if await rnMigration.checkIfNeedToMigrate() {
        _ = await rnMigration.performMigration()
      } else {
        await MainActor.run {
          openOnboarding(deeplink: deeplink)
        }
      }
    }
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
extension String: TKCoordinator.CoordinatorDeeplink {}

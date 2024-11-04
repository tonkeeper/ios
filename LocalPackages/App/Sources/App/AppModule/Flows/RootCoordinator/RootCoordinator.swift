import UIKit
import TKUIKit
import TKCoordinator
import TKCore
import KeeperCore
import TonSwift

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
      handlePasscodeFlowIfNeeded { self.openMain(deeplink: deeplink) }
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

  private func handlePasscodeFlowIfNeeded(completion: @escaping (() -> Void)) {
    
    let isLockScreen = dependencies.keeperCoreRootAssembly.storesAssembly.securityStore.getState().isLockScreen
    let tonProofTokenService = dependencies.keeperCoreRootAssembly.mainAssembly().servicesAssembly.tonProofTokenService()
    let mnemonicRepository = dependencies.keeperCoreRootAssembly.repositoriesAssembly.mnemonicsRepository()
    let missedTonProofWallets = tonProofTokenService.getWalletsWithMissedToken()
    
    guard isLockScreen || !missedTonProofWallets.isEmpty else {
      completion()
      return
    }
    
    showPasscode { passcode in
      guard !missedTonProofWallets.isEmpty else {
        completion()
        return
      }
      Task {
        for wallet in missedTonProofWallets {
          do {
            let mnemonic = try await mnemonicRepository.getMnemonic(wallet: wallet, password: passcode)
            let keyPair = try TonSwift.Mnemonic.mnemonicToPrivateKey(
              mnemonicArray: mnemonic.mnemonicWords
            )
            let pair = WalletPrivateKeyPair(
              wallet: wallet,
              privateKey: keyPair.privateKey
            )
            await tonProofTokenService.loadTokensFor(pairs: [pair])
            await MainActor.run {
              completion()
            }
          } catch {
            continue
          }
        }
      }
    }
  }
  
  private func showPasscode(completion: ((String) -> Void)?) {
    let router = NavigationControllerRouter(rootViewController: TKNavigationController())
    let mnemonicsRepository = dependencies.keeperCoreRootAssembly.repositoriesAssembly.mnemonicsRepository()

    let validator = PasscodeConfirmationValidator(
      mnemonicsRepository: mnemonicsRepository
    )
    let securityStore = dependencies.keeperCoreRootAssembly.storesAssembly.securityStore
    let passcodeBiometry = PasscodeBiometryProvider(
      biometryProvider: BiometryProvider(),
      securityStore: securityStore
    )
    let coordinator = PasscodeInputCoordinator(
      router: router,
      context: .entry,
      validator: validator,
      biometryProvider: passcodeBiometry,
      mnemonicsRepository: mnemonicsRepository,
      securityStore: securityStore
    )

    coordinator.didInputPasscode = { [weak self, weak coordinator] passcode in
      self?.removeChild(coordinator)
      completion?(passcode)
    }

    coordinator.didLogout = { [dependencies, weak coordinator] in
      guard let coordinator else { return }
      let deleteController = dependencies.keeperCoreRootAssembly.mainAssembly().walletDeleteController
      Task {
        await deleteController.deleteAll()
        await MainActor.run {
          self.removeChild(coordinator)
        }
      }
    }

    coordinator.start()
    addChild(coordinator)
    
    showViewController(coordinator.router.rootViewController, animated: false)
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
        let errors = await rnMigration.performMigration()
        if !errors.isEmpty {
          await MainActor.run {
            openOnboarding(deeplink: deeplink)
            let alertController = UIAlertController(title: "Failed migrate",
                                                    message: errors.map { $0.alertValue }.joined(separator: "\n"),
                                                    preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "OK", style: .cancel))
            router.rootViewController.present(alertController, animated: true)
          }
        }
        
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
}

extension KeeperCore.Deeplink: TKCoordinator.CoordinatorDeeplink {}
extension String: TKCoordinator.CoordinatorDeeplink {}

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
  private let pushNotificationsManager: PushNotificationManager

  init(router: ViewControllerRouter,
       dependencies: Dependencies) {
    self.dependencies = dependencies
    self.rootController = dependencies.keeperCoreRootAssembly.rootController()
    self.stateManager = RootCoordinatorStateManager(
      walletsStore: dependencies.keeperCoreRootAssembly.storesAssembly.walletsStore
    )
    self.pushNotificationsManager = PushNotificationManager(
      appSettings: dependencies.coreAssembly.appSettings,
      uniqueIdProvider: dependencies.coreAssembly.uniqueIdProvider,
      pushNotificationTokenProvider: dependencies.coreAssembly.pushNotificationTokenProvider,
      pushNotificationAPI: dependencies.coreAssembly.pushNotificationAPI,
      walletNotificationsStore: dependencies.keeperCoreRootAssembly.storesAssembly.walletNotificationStore
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
      migrateRNIfNeed(deeplink: deeplink) { [weak self] isSuccess in
        if isSuccess {
          self?.stateManager.didPerformRNMigration()
        } else {
          self?.openOnboarding(deeplink: deeplink)
        }
      }
    case .main:
      migrateNativeIfNeed { [weak self] didNeedToMigrate, isSuccess in
        if !isSuccess {
          self?.openOnboarding(deeplink: deeplink)
          return
        }
        if didNeedToMigrate {
          self?.openMain(deeplink: deeplink)
        } else {
          self?.handlePasscodeFlowIfNeeded { self?.openMain(deeplink: deeplink) }
        }
      }
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
    let mnemonicRepository = dependencies.keeperCoreRootAssembly.secureAssembly.mnemonicsRepository()
    let missedTonProofWallets = tonProofTokenService.getWalletsWithMissedToken()
    
    guard isLockScreen || !missedTonProofWallets.isEmpty else {
      completion()
      return
    }
    
    showPasscode(mnemonicsRepository: dependencies.keeperCoreRootAssembly.secureAssembly.mnemonicsRepository()) { passcode in
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
          } catch {
            continue
          }
        }
        await MainActor.run {
          completion()
        }
      }
    }
  }
  
  private func showPasscode(mnemonicsRepository: MnemonicsRepository,
                            completion: ((String) -> Void)?) {
    let router = NavigationControllerRouter(rootViewController: TKNavigationController())

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
  
  func handleMigrationResult(_ result: MergeMigration.MigrationResult,
                             completion: @escaping (_ isSuccess: Bool) -> Void) {
    let title: String
    var description: String
    switch result {
    case .failedMigrateMnemonics(let error):
      title = "Migration failed"
      description = "Failed migrate mnemonics \(error.localizedDescription)"
      completion(false)
    case .failedMigrateWallets(let error):
      title = "Migration failed"
      description = "Failed migrate wallets \(error.localizedDescription)"
      completion(false)
    case .partialy(let failedWallets):
      title = "Failed migrate some wallets"
      description = failedWallets.map { "Name: \($0.name)\nType: \($0.type), \nPublicKey: \($0.pubkey)" }.joined(separator: "\n\n")
      completion(true)
    case .success:
      completion(true)
      return
    }
    
    description += "\n\n Your seed phrases are safe!"
    
    let alertController = UIAlertController(title: title,
                                            message: description,
                                            preferredStyle: .alert)
    alertController.addAction(UIAlertAction(title: "OK", style: .default))
    
    router.rootViewController.topPresentedViewController().present(alertController, animated: true)
  }
  
  func migrateNativeIfNeed(completion: @escaping (_ didNeedToMigrate: Bool, _ isSuccess: Bool) -> Void) {
    let mergeMigration = MergeMigration(
      asyncStorage: dependencies.keeperCoreRootAssembly.rnAssembly.rnAsyncStorage,
      appInfoProvider: dependencies.coreAssembly.appInfoProvider,
      mnemonicsRepository: dependencies.keeperCoreRootAssembly.coreAssembly.mnemonicsVault(),
      rnMnemonicsRepository: dependencies.keeperCoreRootAssembly.coreAssembly.rnMnemonicsVault(),
      keeperInfoRepository: dependencies.keeperCoreRootAssembly.repositoriesAssembly.keeperInfoRepository(),
      keeperInfoStore: dependencies.keeperCoreRootAssembly.storesAssembly.keeperInfoStore,
      tonProofTokenService: dependencies.keeperCoreRootAssembly.servicesAssembly.tonProofTokenService()
    )
    
    guard mergeMigration.isNeedToMigrateFromNative() else {
      completion(false, true)
      return
    }
    
    mergeMigration.performNativeMigration { [weak self] passcodeCompletion in
      guard let self else { return }
      showPasscode(mnemonicsRepository: dependencies.keeperCoreRootAssembly.secureAssembly.rnMnemonicsRepository()) { passcode in
        passcodeCompletion(passcode)
      }
    } completion: { [weak self] result in
      self?.handleMigrationResult(result, completion: { isSuccess in
        completion(true, isSuccess)
      })
    }
  }
  
  func migrateRNIfNeed(deeplink: CoordinatorDeeplink?, completion: @escaping (_ isSuccess: Bool) -> Void) {
    let mergeMigration = MergeMigration(
      asyncStorage: dependencies.keeperCoreRootAssembly.rnAssembly.rnAsyncStorage,
      appInfoProvider: dependencies.coreAssembly.appInfoProvider,
      mnemonicsRepository: dependencies.keeperCoreRootAssembly.coreAssembly.mnemonicsVault(),
      rnMnemonicsRepository: dependencies.keeperCoreRootAssembly.coreAssembly.rnMnemonicsVault(),
      keeperInfoRepository: dependencies.keeperCoreRootAssembly.repositoriesAssembly.keeperInfoRepository(),
      keeperInfoStore: dependencies.keeperCoreRootAssembly.storesAssembly.keeperInfoStore,
      tonProofTokenService: dependencies.keeperCoreRootAssembly.servicesAssembly.tonProofTokenService()
    )
    
    let mnemonicsRepository = dependencies.keeperCoreRootAssembly.secureAssembly.rnMnemonicsRepository()
    
    Task { @MainActor [weak self] in
      guard let self else { return }
      guard await mergeMigration.isNeedToMigrateFromRN() else {
        openOnboarding(deeplink: deeplink)
        return
      }
      let result = await mergeMigration.performRNMigration { [weak self] passcodeCompletion in
        guard let self else { return }
        DispatchQueue.main.async {
          self.showPasscode(mnemonicsRepository: mnemonicsRepository) { passcode in
            passcodeCompletion(passcode)
          }
        }
      }
      handleMigrationResult(result) { isSuccess in
        completion(isSuccess)
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

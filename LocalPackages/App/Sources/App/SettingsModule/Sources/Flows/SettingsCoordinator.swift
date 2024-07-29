import UIKit
import TKCoordinator
import TKUIKit
import TKCore
import KeeperCore

final class SettingsCoordinator: RouterCoordinator<NavigationControllerRouter> {
  var didFinish: (() -> Void)?
  
  private let wallet: Wallet
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  private let coreAssembly: TKCore.CoreAssembly
  
  init(wallet: Wallet,
       keeperCoreMainAssembly: KeeperCore.MainAssembly,
       coreAssembly: TKCore.CoreAssembly,
       router: NavigationControllerRouter) {
    self.wallet = wallet
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    self.coreAssembly = coreAssembly
    super.init(router: router)
  }
  
  public override func start() {
    openSettingsRoot()
  }
}

private extension SettingsCoordinator {
  func openSettingsRoot() {
    let configurator = SettingsListRootConfigurator(
      walletId: wallet.id,
      walletsStore: keeperCoreMainAssembly.walletAssembly.walletsStore,
      currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore,
      mnemonicsRepository: keeperCoreMainAssembly.repositoriesAssembly.mnemonicsRepository(),
      appStoreReviewer: coreAssembly.appStoreReviewer(),
      configurationStore: keeperCoreMainAssembly.configurationAssembly.remoteConfigurationStore,
      walletDeleteController: keeperCoreMainAssembly.walletDeleteController,
      anaylticsProvider: coreAssembly.analyticsProvider
    )
    
    configurator.didOpenURL = { [coreAssembly] in
      coreAssembly.urlOpener().open(url: $0)
    }
    
    configurator.didShowAlert = { [weak self] title, description, actions in
      let alertController = UIAlertController(title: title, message: description, preferredStyle: .alert)
      actions.forEach { action in alertController.addAction(action) }
      self?.router.rootViewController.present(alertController, animated: true)
    }
    
    configurator.didTapEditWallet = { [weak self] wallet in
      self?.openEditWallet(wallet: wallet)
    }
    
    configurator.didTapCurrencySettings = { [weak self] in
      self?.openCurrencyPicker()
    }
    
    configurator.didTapSecuritySettings = { [weak self] in
      self?.openSecurity()
    }
    
    configurator.didTapBackup = { [weak self, wallet] in
      self?.openBackup(wallet: wallet)
    }
    
    configurator.didTapDeleteRegularWallet = { [weak self] wallet in
      self?.deleteRegular(wallet: wallet)
    }
    
    configurator.didDeleteWallet = { [weak self] in
      guard let self else { return }
      let wallets = self.keeperCoreMainAssembly.walletAssembly.walletsStore.getState().wallets
      if !wallets.isEmpty {
        self.router.pop(animated: true)
      }
    }
    
    let module = SettingsListAssembly.module(configurator: configurator)
    
    module.viewController.setupBackButton()
    
    router.push(viewController: module.viewController,
                onPopClosures: { [weak self] in
      self?.didFinish?()
    })
  }
  
  func openEditWallet(wallet: Wallet) {
    let addWalletModuleModule = AddWalletModule(
      dependencies: AddWalletModule.Dependencies(
        walletsUpdateAssembly: keeperCoreMainAssembly.walletUpdateAssembly,
        storesAssembly: keeperCoreMainAssembly.storesAssembly,
        coreAssembly: coreAssembly,
        scannerAssembly: keeperCoreMainAssembly.scannerAssembly()
      )
    )
    
    let module = addWalletModuleModule.createCustomizeWalletModule(
      name: wallet.label,
      tintColor: wallet.tintColor,
      icon: wallet.metaData.icon,
      configurator: EditWalletCustomizeWalletViewModelConfigurator()
    )
    
    module.output.didCustomizeWallet = { [weak self] model in
      self?.updateWallet(wallet: wallet, model: model)
    }
    
    let navigationController = TKNavigationController(rootViewController: module.view)
    
    module.view.setupRightCloseButton { [weak navigationController] in
      navigationController?.dismiss(animated: true)
    }
    
    router.present(navigationController)
  }
  
  func updateWallet(wallet: Wallet, model: CustomizeWalletModel) {
    let updater = keeperCoreMainAssembly.walletUpdateAssembly.walletsStoreUpdater
    Task {
      await updater.updateWalletMetaData(wallet, metaData: WalletMetaData(customizeWalletModel: model))
    }
  }
  
  func openCurrencyPicker() {
    let configuration = SettingsListCurrencyPickerConfigurator(
      currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore
    )
    let module = SettingsListAssembly.module(configurator: configuration)
    module.viewController.setupBackButton()

    router.push(viewController: module.viewController)
  }
  
  func openBackup(wallet: Wallet) {
    let configuration = SettingsListBackupConfigurator(
      walletId: wallet.id,
      walletsStore: keeperCoreMainAssembly.walletAssembly.walletsStore,
      dateFormatter: keeperCoreMainAssembly.formattersAssembly.dateFormatter
    )
    
    configuration.didTapBackupManually = { [weak self] in
      self?.openManuallyBackup(wallet: wallet)
    }
    
    configuration.didTapShowRecoveryPhrase = { [weak self] in
      self?.openRecoveryPhrase(wallet: wallet)
    }
  
    let module = SettingsListAssembly.module(configurator: configuration)
    module.viewController.setupBackButton()

    router.push(viewController: module.viewController)
  }
  
  func openSecurity() {
    let configuration = SettingsListSecurityConfigurator(
      securityStore: keeperCoreMainAssembly.storesAssembly.securityStore,
      mnemonicsRepository: keeperCoreMainAssembly.repositoriesAssembly.mnemonicsRepository(),
      biometryProvider: BiometryProvider()
    )
    
    configuration.didRequirePasscode = { [weak self] in
      await self?.getPasscode()
    }
    
    configuration.didTapChangePasscode = { [openChangePasscode] in
      openChangePasscode()
    }
    
    let module = SettingsListAssembly.module(configurator: configuration)
    module.viewController.setupBackButton()

    router.push(viewController: module.viewController)
  }
  
  func openRecoveryPhrase(wallet: Wallet) {
    let coordinator = SettingsRecoveryPhraseCoordinator(
      wallet: wallet,
      keeperCoreMainAssembly: keeperCoreMainAssembly,
      coreAssembly: coreAssembly,
      router: router
    )
    
    coordinator.didFinish = { [weak self, weak coordinator] in
      guard let coordinator else { return }
      self?.removeChild(coordinator)
    }
    
    addChild(coordinator)
    coordinator.start()
  }
  
  func openManuallyBackup(wallet: Wallet) {
    let coordinator = BackupModule(
      dependencies: BackupModule.Dependencies(
        keeperCoreMainAssembly: keeperCoreMainAssembly,
        coreAssembly: coreAssembly
      )
    ).createBackupCoordinator(
      router: router,
      wallet: wallet
    )
    
    coordinator.didFinish = { [weak self, weak coordinator] in
      guard let coordinator else { return }
      self?.removeChild(coordinator)
    }
    
    addChild(coordinator)
    coordinator.start()
  }
  
  func openChangePasscode() {
    let navigationController = TKNavigationController()
    navigationController.configureTransparentAppearance()
    
    let coordinator = PasscodeChangeCoordinator(
      router: NavigationControllerRouter(
        rootViewController: navigationController
      ),
      keeperCoreAssembly: keeperCoreMainAssembly
    )
    
    coordinator.didCancel = { [weak self, weak coordinator] in
      guard let coordinator else { return }
      self?.removeChild(coordinator)
      self?.router.dismiss(animated: true)
    }
    
    coordinator.didChangePasscode = { [weak self, weak coordinator] in
      guard let coordinator else { return }
      self?.removeChild(coordinator)
      self?.router.dismiss(animated: true)
    }
    
    addChild(coordinator)
    coordinator.start()
    
    router.present(coordinator.router.rootViewController, 
                   onDismiss: { [weak self, weak coordinator] in
      guard let coordinator else { return }
      self?.removeChild(coordinator)
    })
  }
  
  func deleteRegular(wallet: Wallet) {
    let viewController = SettingsDeleteWarningViewController()
    let bottomSheetViewController = TKBottomSheetViewController(contentViewController: viewController)

    viewController.didTapSignOut = { [weak bottomSheetViewController, weak self] in
      bottomSheetViewController?.dismiss(completion: {
        guard let self else { return }
        Task {
          guard let passcode = await self.getPasscode() else { return }
          await self.keeperCoreMainAssembly.walletDeleteController.deleteWallet(wallet: wallet, passcode: passcode)
          await MainActor.run {
            let wallets = self.keeperCoreMainAssembly.walletAssembly.walletsStore.getState().wallets
            if !wallets.isEmpty {
              self.router.pop(animated: true)
            }
          }
        }
      })
    }
    
    viewController.didTapBackup = { [weak bottomSheetViewController, weak self] in
      bottomSheetViewController?.dismiss(completion: {
        if wallet.isBackupAvailable {
          if wallet.hasBackup {
            self?.openRecoveryPhrase(wallet: wallet)
          } else {
            self?.openManuallyBackup(wallet: wallet)
          }
        }
      })
    }
    
    bottomSheetViewController.present(fromViewController: router.rootViewController)
  }
  
  func getPasscode() async -> String? {
    return await PasscodeInputCoordinator.getPasscode(
      parentCoordinator: self,
      parentRouter: router,
      mnemonicsRepository: keeperCoreMainAssembly.repositoriesAssembly.mnemonicsRepository(),
      securityStore: keeperCoreMainAssembly.storesAssembly.securityStore
    )
  }
}

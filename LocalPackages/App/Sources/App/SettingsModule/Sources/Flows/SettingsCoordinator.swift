import UIKit
import TKCoordinator
import TKUIKit
import TKCore
import KeeperCore

final class SettingsCoordinator: RouterCoordinator<NavigationControllerRouter> {
  var didFinish: (() -> Void)?
  var didLogout: (() -> Void)?
  
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  private let coreAssembly: TKCore.CoreAssembly
  
  init(keeperCoreMainAssembly: KeeperCore.MainAssembly,
       coreAssembly: TKCore.CoreAssembly,
       router: NavigationControllerRouter) {
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
    let itemsProvider = SettingsRootListItemsProvider(
      settingsController: keeperCoreMainAssembly.settingsController,
      urlOpener: coreAssembly.urlOpener(),
      appStoreReviewer: coreAssembly.appStoreReviewer(),
      appSettings: coreAssembly.appSettings
    )
    let module = SettingsListAssembly.module(itemsProvider: itemsProvider)
    
    itemsProvider.didTapEditWallet = { [weak self] wallet in
      self?.openEditWallet(wallet: wallet)
    }
    
    itemsProvider.didTapCurrency = { [weak self] in
      self?.openCurrencyPicker()
    }
    
    itemsProvider.didTapTheme = { [weak self] in
      self?.openThemePicker()
    }
    
    itemsProvider.didTapBackup = { [weak self] wallet in
      self?.openBackup(wallet: wallet)
    }
    
    itemsProvider.didTapSecurity = { [weak self] in
      self?.openSecurity()
    }
    
    itemsProvider.didShowAlert = { [weak self] title, description, actions in
      let alertController = UIAlertController(title: title, message: description, preferredStyle: .alert)
      actions.forEach { action in alertController.addAction(action) }
      self?.router.rootViewController.present(alertController, animated: true)
    }
    
    itemsProvider.didTapLogout = { [weak self] in
      self?.didLogout?()
    }
    
    itemsProvider.didTapDeleteAccount = { [weak self] in
      self?.router.pop()
    }

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
      name: wallet.metaData.label,
      tintColor: wallet.metaData.tintColor,
      emoji: wallet.metaData.emoji,
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
    let controller = keeperCoreMainAssembly.walletUpdateAssembly.walletUpdateController()
    let metaData = WalletMetaData(
      label: model.name,
      tintColor: model.tintColor,
      emoji: model.emoji)
    do {
      try controller.updateWallet(wallet: wallet, metaData: metaData)
    } catch {
      print("Log: Wallet update failed")
    }
  }
  
  func openCurrencyPicker() {
    let itemsProvider = SettingsCurrencyPickerListItemsProvider(settingsController: keeperCoreMainAssembly.settingsController)
    let module = SettingsListAssembly.module(itemsProvider: itemsProvider)
    
    router.push(viewController: module.viewController)
  }
  
  func openThemePicker() {
    let itemsProvider = SettingsThemePickerListItemsProvider(appSettings: coreAssembly.appSettings)
    let module = SettingsListAssembly.module(itemsProvider: itemsProvider)
    
    router.push(viewController: module.viewController)
  }
  
  func openBackup(wallet: Wallet) {
    let itemsProvider = SettingsBackupListItemsProvider(
      backupController: keeperCoreMainAssembly.backupController(wallet: wallet)
    )
    
    itemsProvider.didTapBackupManually = { [weak self] in
      self?.openManuallyBackup(wallet: wallet)
    }
    
    itemsProvider.didTapShowRecoveryPhrase = { [weak self] in
      self?.openRecoveryPhrase(wallet: wallet)
    }
    
    let module = SettingsListAssembly.module(itemsProvider: itemsProvider)
    
    router.push(viewController: module.viewController)
  }
  
  func openSecurity() {
    let itemsProvider = SettingsSecurityListItemsProvider(
      securityStore: keeperCoreMainAssembly.storesAssembly.securityStore,
      mnemonicsRepository: keeperCoreMainAssembly.repositoriesAssembly.mnemonicsRepository(),
      biometryProvider: BiometryProvider()
    )
    
    itemsProvider.didTapChangePasscode = { [weak self] in
      self?.openChangePasscode()
    }
    
    itemsProvider.didRequirePasscode = { [weak self] in
      await self?.getPasscode()
    }
    
    let module = SettingsListAssembly.module(itemsProvider: itemsProvider)
    
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
  
  func getPasscode() async -> String? {
    return await PasscodeInputCoordinator.getPasscode(
      parentCoordinator: self,
      parentRouter: router,
      mnemonicsRepository: keeperCoreMainAssembly.repositoriesAssembly.mnemonicsRepository(),
      securityStore: keeperCoreMainAssembly.storesAssembly.securityStore
    )
  }
}

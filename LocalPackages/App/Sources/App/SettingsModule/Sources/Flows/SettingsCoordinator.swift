import UIKit
import TKCoordinator
import TKUIKit
import TKCore
import KeeperCore

final class SettingsCoordinator: RouterCoordinator<NavigationControllerRouter> {
  var didFinish: (() -> Void)?
  
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
      appStoreReviewer: coreAssembly.appStoreReviewer()
    )
    let module = SettingsListAssembly.module(itemsProvider: itemsProvider)
    
    itemsProvider.didTapEditWallet = { [weak self] wallet in
      self?.openEditWallet(wallet: wallet)
    }
    
    itemsProvider.didTapCurrency = { [weak self] in
      self?.openCurrencyPicker()
    }
    
    itemsProvider.didTapBackup = { [weak self] wallet in
      self?.openBackup(wallet: wallet)
    }

    router.push(viewController: module.viewController,
                onPopClosures: { [weak self] in
      self?.didFinish?()
    })
  }
  
  func openEditWallet(wallet: Wallet) {
    let addWalletModuleModule = AddWalletModule(
      dependencies: AddWalletModule.Dependencies(
        walletsUpdateAssembly: keeperCoreMainAssembly.walletUpdateAssembly
      )
    )
    
    let module = addWalletModuleModule.createCustomizeWalletModule(wallet: wallet)
    
    module.output.didCustomizeWallet = { [weak self] model in
      self?.updateWallet(wallet: wallet, model: model)
      module.view.dismiss(animated: true)
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
      colorIdentifier: model.colorIdentifier,
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
}

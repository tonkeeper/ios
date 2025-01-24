import UIKit
import TKCoordinator
import TKUIKit
import TKCore
import TKLocalize
import KeeperCore
import CoreComponents
import TKLocalize
import TKStories
import Stories

final class SettingsCoordinator: RouterCoordinator<NavigationControllerRouter> {
  var didTapBattery: ((Wallet) -> Void)?
  
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

  func presentAlertController(title: String, message: String?, actions: [UIAlertAction]) {
    let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
    actions.forEach { action in alertController.addAction(action) }
    router.rootViewController.present(alertController, animated: true)
  }

  func openSettingsRoot() {
    let configurator = SettingsListRootConfigurator(
      wallet: wallet,
      walletsStore: keeperCoreMainAssembly.storesAssembly.walletsStore,
      currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore,
      appSettingsStore: keeperCoreMainAssembly.storesAssembly.appSettingsStore,
      mnemonicsRepository: keeperCoreMainAssembly.secureAssembly.mnemonicsRepository(),
      appStoreReviewer: coreAssembly.appStoreReviewer(),
      configuration: keeperCoreMainAssembly.configurationAssembly.configuration,
      walletDeleteController: keeperCoreMainAssembly.walletDeleteController,
      anaylticsProvider: coreAssembly.analyticsProvider
    )
    
    configurator.didOpenURL = { [coreAssembly] in
      coreAssembly.urlOpener().open(url: $0)
    }
    
    configurator.didShowAlert = { [weak self] title, description, actions in
      self?.presentAlertController(title: title, message: description, actions: actions)
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
    
    configurator.didTapLegal = { [weak self] in
      self?.openLegal()
    }
    
    configurator.didTapBackup = { [weak self, wallet] in
      self?.openBackup(wallet: wallet)
    }
    
    configurator.didTapSignOutRegularWallet = { [weak self] wallet in
      self?.deleteRegular(wallet: wallet, isSignOut: true)
    }
    
    configurator.didTapDeleteRegularWallet = { [weak self] wallet in
      self?.deleteRegular(wallet: wallet, isSignOut: false)
    }
    
    configurator.didTapNotifications = { [weak self] wallet in
      self?.openNotifications(wallet: wallet)
    }
    
    configurator.didTapW5Wallet = { [weak self] wallet in
      self?.openW5Story(wallet: wallet)
    }
    
    configurator.didTapV4Wallet = { [weak self] wallet in
      self?.addV4Wallet(wallet: wallet)
    }
    
    configurator.didTapBattery = { [weak self] wallet in
      self?.didTapBattery?(wallet)
    }

    configurator.didTapConnectedApps = { [weak self] wallet in
      self?.openConnectedApps(wallet: wallet)
    }

    configurator.didDeleteWallet = { [weak self] in
      guard let self else { return }
      let wallets = self.keeperCoreMainAssembly.storesAssembly.walletsStore.wallets
      if !wallets.isEmpty {
        self.router.pop(animated: true)
      }
    }
    
    let module = SettingsListAssembly.module(configurator: configurator)
    
    module.output.didOpenDevMenu = { [weak self] in
      self?.openDevMenu()
    }
    
    module.viewController.setupBackButton()
    
    router.push(viewController: module.viewController,
                onPopClosures: { [weak self] in
      self?.didFinish?(self)
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
  
  func didTapAddW5Wallet(wallet: Wallet) {
    let coordinator = AddWalletModule(
      dependencies: AddWalletModule.Dependencies(
        walletsUpdateAssembly: keeperCoreMainAssembly.walletUpdateAssembly,
        storesAssembly: keeperCoreMainAssembly.storesAssembly,
        coreAssembly: coreAssembly,
        scannerAssembly: keeperCoreMainAssembly.scannerAssembly()
      )
    ).createAddDifferentRevisionWalletCoordinator(
      wallet: wallet,
      revisionToAdd: .v5R1,
      router: ViewControllerRouter(rootViewController: router.rootViewController)
    )
    
    coordinator.didAddedWallet = { [weak self] in
      self?.router.pop(animated: true)
    }
    
    addChild(coordinator)
    coordinator.start()
  }
  
  func openW5Story(wallet: Wallet) {
    let storiesViewController = TKStoriesFactory.storiesViewController(
      models: [
        StoriesPageModel(
          title: TKLocales.W5Stories.Gasless.title,
          description: TKLocales.W5Stories.Gasless.subtitle,
          backgroundImage: .image(.TKUIKit.Images.storyGasless)
        ),
        StoriesPageModel(
          title: TKLocales.W5Stories.Messages.title,
          description: TKLocales.W5Stories.Messages.subtitle,
          backgroundImage: .image(.TKUIKit.Images.storyMessages)
        ),
        StoriesPageModel(
          title: TKLocales.W5Stories.Phrase.title,
          description: TKLocales.W5Stories.Phrase.subtitle,
          button: StoriesPageModel.Button(
            title: TKLocales.W5Stories.Phrase.button,
            action: { [weak self] in
              self?.router.dismiss(animated: true, completion: {
                self?.didTapAddW5Wallet(wallet: wallet)
              })
            }
          ),
          backgroundImage: .image(.TKUIKit.Images.storyPhrase)
        )
      ]
    )
    router.present(storiesViewController)
  }
  
  func addV4Wallet(wallet: Wallet) {
    let coordinator = AddWalletModule(
      dependencies: AddWalletModule.Dependencies(
        walletsUpdateAssembly: keeperCoreMainAssembly.walletUpdateAssembly,
        storesAssembly: keeperCoreMainAssembly.storesAssembly,
        coreAssembly: coreAssembly,
        scannerAssembly: keeperCoreMainAssembly.scannerAssembly()
      )
    ).createAddDifferentRevisionWalletCoordinator(
      wallet: wallet,
      revisionToAdd: .v4R2,
      router: ViewControllerRouter(
        rootViewController: router.rootViewController
      )
    )
    
    coordinator.didAddedWallet = { [weak self] in
      self?.router.pop(animated: true)
    }
    
    addChild(coordinator)
    coordinator.start()
  }
  
  func updateWallet(wallet: Wallet, model: CustomizeWalletModel) {
    let walletsStore = keeperCoreMainAssembly.storesAssembly.walletsStore
    Task {
      await walletsStore.updateWalletMetaData(
        wallet,
        metaData: WalletMetaData(customizeWalletModel: model)
      )
    }
  }
  
  func openCurrencyPicker() {
    let configuration = SettingsListCurrencyPickerConfigurator(
      currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore
    )
    configuration.didSelect = { [weak self] in
      self?.router.pop()
    }
    let module = SettingsListAssembly.module(configurator: configuration)
    module.viewController.setupBackButton()

    router.push(viewController: module.viewController)
  }
  
  func openBackup(wallet: Wallet) {
    let configuration = SettingsListBackupConfigurator(
      wallet: wallet,
      walletsStore: keeperCoreMainAssembly.storesAssembly.walletsStore,
      processedBalanceStore: keeperCoreMainAssembly.storesAssembly.processedBalanceStore,
      dateFormatter: keeperCoreMainAssembly.formattersAssembly.dateFormatter,
      amountFormatter: keeperCoreMainAssembly.formattersAssembly.decimalAmountFormatter
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
      mnemonicsRepository: keeperCoreMainAssembly.secureAssembly.mnemonicsRepository(),
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
    
    coordinator.didFinish = { [weak self] in
      self?.removeChild($0)
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
    
    coordinator.didFinish = { [weak self] in
      self?.removeChild($0)
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
  
  func deleteRegular(wallet: Wallet, isSignOut: Bool) {
    let viewController = SettingsDeleteWarningViewController(
      popupTitle: isSignOut ? TKLocales.SignOutWarning.title : TKLocales.DeleteWalletWarning.title,
      popupCaption: isSignOut ? TKLocales.SignOutWarning.caption : TKLocales.DeleteWalletWarning.caption,
      buttonTitle: isSignOut ? TKLocales.Actions.signOut : TKLocales.DeleteWalletWarning.button,
      walletName: wallet.iconWithName(
        attributes: TKTextStyle.body1.getAttributes(color: .Text.primary),
        iconColor: .Icon.primary,
        iconSide: 20
      )
    )
    let bottomSheetViewController = TKBottomSheetViewController(contentViewController: viewController)

    viewController.didTapSignOut = { [weak bottomSheetViewController, weak self] in
      bottomSheetViewController?.dismiss(completion: {
        guard let self else { return }
        Task {
          guard let passcode = await self.getPasscode() else { return }
          await self.keeperCoreMainAssembly.walletDeleteController.deleteWallet(wallet: wallet, passcode: passcode)
          await MainActor.run {
            let wallets = self.keeperCoreMainAssembly.storesAssembly.walletsStore.wallets
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
  
  func openLegal() {
    let configuration = SettingsListLegalConfigurator()
    
    let module = SettingsListAssembly.module(configurator: configuration)
    module.viewController.setupBackButton()
    
    configuration.didTapFontLicense = { [weak self] in
      let viewController = FontLicenseViewController()
      viewController.setupBackButton()
      self?.router.push(viewController: viewController)
    }
    
    configuration.openUrl = { [coreAssembly] url in
      coreAssembly.urlOpener().open(url: url)
    }

    router.push(viewController: module.viewController)
  }
  
  func openNotifications(wallet: Wallet) {
    let configuration = SettingsListNotificationsConfigurator(
    wallet: wallet,
    walletNotificationStore: keeperCoreMainAssembly.storesAssembly.walletNotificationStore,
    notificationsService: keeperCoreMainAssembly.servicesAssembly.notificationsService(
      walletNotificationsStore: keeperCoreMainAssembly.storesAssembly.walletNotificationStore,
      tonConnectAppsStore: keeperCoreMainAssembly.tonConnectAssembly.tonConnectAppsStore
    ),
    tonConnectAppsStore: keeperCoreMainAssembly.tonConnectAssembly.tonConnectAppsStore,
    urlOpener: coreAssembly.urlOpener(),
    pushTokenProvider: PushNotificationTokenProvider()
    )
    
    let module = SettingsListAssembly.module(configurator: configuration)
    module.viewController.setupBackButton()

    router.push(viewController: module.viewController)
  }
  
  func getPasscode() async -> String? {
    return await PasscodeInputCoordinator.getPasscode(
      parentCoordinator: self,
      parentRouter: router,
      mnemonicsRepository: keeperCoreMainAssembly.secureAssembly.mnemonicsRepository(),
      securityStore: keeperCoreMainAssembly.storesAssembly.securityStore
    )
  }
  
  func getRNPasscode() async -> String? {
    return await PasscodeInputCoordinator.getPasscode(
      parentCoordinator: self,
      parentRouter: router,
      mnemonicsRepository: keeperCoreMainAssembly.secureAssembly.rnMnemonicsRepository(),
      securityStore: keeperCoreMainAssembly.storesAssembly.securityStore
    )
  }

  func openConnectedApps(wallet: Wallet) {
    let tonConnectAppsStore = keeperCoreMainAssembly.tonConnectAssembly.tonConnectAppsStore
    let connectedAppsStore = keeperCoreMainAssembly.storesAssembly.connectedAppsStore(
      tonConnectAppsStore: tonConnectAppsStore
    )
    let configurator = SettingsListConnectedAppsConfigurator(connectedAppsStore: connectedAppsStore)
    configurator.didRequestShowAlert = { [weak self] title, actions in
      self?.presentAlertController(title: title, message: nil, actions: actions)
    }
    
    let module = SettingsListAssembly.module(configurator: configurator)
    router.push(viewController: module.viewController)
  }

  func openDevMenu() {
    let storiesAssembly = Stories.Assembly(
      keeperCoreAssembly: keeperCoreMainAssembly,
      coreAssembly: coreAssembly
    )
    
    let configuration = SettingsListDevMenuConfigurator(
      uniqueIdProvider: coreAssembly.uniqueIdProvider,
      storiesService: storiesAssembly.storiesService()
    )
    configuration.didSelectRNSeedPhrasesRecovery = {
      Task { @MainActor [weak self] in
        guard let self,
              let passcode = await self.getRNPasscode() else { return }
        let mnemonicsVault = self.keeperCoreMainAssembly.coreAssembly.rnMnemonicsVault()
        guard let mnemonics = try? await mnemonicsVault.getMnemonics(password: passcode) else {
          return
        }
        self.openSeedPhrases(mnemonics: mnemonics)
      }
    }
    configuration.didSelectSeedPhrasesRecovery = {
      Task { @MainActor [weak self] in
        guard let self,
              let passcode = await self.getPasscode() else { return }
        let mnemonicsVault = self.keeperCoreMainAssembly.coreAssembly.mnemonicsVault()
        guard let mnemonics = try? await mnemonicsVault.getMnemonics(password: passcode) else {
          return
        }
        self.openSeedPhrases(mnemonics: mnemonics)
      }
    }
    
    let module = SettingsListAssembly.module(configurator: configuration)
    module.viewController.setupBackButton()

    router.push(viewController: module.viewController)
  }
  
  func openSeedPhrases(mnemonics: Mnemonics) {
    let configuration = SettingsListRNWalletsSeedPhrasesConfigurator(
      mnemonics: mnemonics
    )
    let module = SettingsListAssembly.module(configurator: configuration)
    module.viewController.setupBackButton()

    router.push(viewController: module.viewController)
  }
}
